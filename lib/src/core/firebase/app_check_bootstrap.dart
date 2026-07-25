import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Controls which App Check provider is used in release builds.
///
/// Defaults to `false` — sideloaded / non-Play-Store release builds use
/// AndroidDebugProvider so they are not rejected by Play Integrity's
/// APP_RECOGNITION_VERDICT (which returns UNRECOGNIZED_VERSION for
/// apps not distributed through Google Play).
///
/// Set to `true` (via --dart-define=FIREBASE_APP_CHECK_USE_PRODUCTION_ATTESTATION=true)
/// ONLY when the app is published on Google Play Store.
///
/// When using AndroidDebugProvider in release, the App Check debug token
/// printed to logcat must be registered once in Firebase Console →
/// App Check → Manage debug tokens (or set App Check to Monitor mode).
const bool kAppCheckProductionAttestation = bool.fromEnvironment(
  'FIREBASE_APP_CHECK_USE_PRODUCTION_ATTESTATION',
  defaultValue: false,
);

const String _webRecaptchaSiteKey = String.fromEnvironment(
  'FIREBASE_APP_CHECK_WEB_RECAPTCHA_SITE_KEY',
  defaultValue: '',
);

/// `enterprise` (default) or `v3` — must match how the key was registered in App Check.
const String _webProviderKind = String.fromEnvironment(
  'FIREBASE_APP_CHECK_WEB_PROVIDER',
  defaultValue: 'enterprise',
);

/// Optional fixed App Check debug token for web (`WebDebugProvider`); register in Firebase Console.
const String _webDebugToken = String.fromEnvironment(
  'FIREBASE_APP_CHECK_WEB_DEBUG_TOKEN',
  defaultValue: '',
);

Future<void> _tryWarmWebAppCheckTokenAfterActivate() async {
  try {
    await FirebaseAppCheck.instance.getToken(true);
    if (kDebugMode) {
      debugPrint('[AppCheck] web warmup getToken(forceRefresh=true) ok');
    }
  } catch (e, st) {
    final text = e.toString();
    if (kDebugMode) {
      debugPrint('[AppCheck] web warmup getToken failed: $e');
      debugPrintStack(stackTrace: st, label: '[AppCheck]');
    }
    if (text.contains('403') || text.contains('fetch-status-error')) {
      debugPrint(
        '[AppCheck] HTTP 403 on token exchange usually means an unregistered or '
        'mismatched web debug token.\n'
        '[AppCheck] Option A: Register the exact UUID from the nearby log line '
        '`App Check debug token: …` (Flutter terminal and/or browser console) under '
        'Firebase Console → App Check → Manage debug tokens for this web app — then '
        'cold-restart flutter run.\n'
        '[AppCheck] Option B: Use Console "Generate token", save it there, pin the '
        'same UUID with --dart-define=FIREBASE_APP_CHECK_WEB_DEBUG_TOKEN=<uuid>; '
        'do not mix a Console-only token with an auto-generated SDK token.\n'
        '[AppCheck] See docs/firebase_integration_setup.md (403 / fetch-status-error).',
      );
    }
  }
}

Future<void> activateFirebaseAppCheckBootstrap() async {
  final AndroidAppCheckProvider providerAndroidResolved;
  final AppleAppCheckProvider providerAppleResolved;
  if (kDebugMode || !kAppCheckProductionAttestation) {
    // Debug builds AND sideloaded release builds: use the debug provider.
    //
    // Play Integrity (production) rejects sideloaded APKs with
    // UNRECOGNIZED_VERSION, causing "App Check token is invalid" on ALL
    // Firebase operations (login, OTP, Firestore) when enforcement is on.
    //
    // The Firebase SDK prints the App Check debug token to logcat:
    //   adb logcat | findstr "AppCheck"
    // Register that token once in:
    //   Firebase Console → App Check → Apps → com.isc.wai → Manage debug tokens
    //
    // OR set App Check to "Monitor" (not Enforce) in Firebase Console to
    // allow all requests while still collecting metrics.
    providerAndroidResolved = const AndroidDebugProvider();
    providerAppleResolved = const AppleDebugProvider();
  } else {
    // Play Store release builds only (--dart-define=FIREBASE_APP_CHECK_USE_PRODUCTION_ATTESTATION=true).
    // Play Integrity works correctly when the app is distributed via Google Play.
    providerAndroidResolved = const AndroidPlayIntegrityProvider();
    providerAppleResolved = const AppleDeviceCheckProvider();
  }
  debugPrint(
    '[AppCheck] activate '
    'android=${providerAndroidResolved.runtimeType} '
    'apple=${providerAppleResolved.runtimeType} '
    'productionAttestation=$kAppCheckProductionAttestation '
    'debugMode=$kDebugMode',
  );

  if (kIsWeb) {
    final siteKey = _webRecaptchaSiteKey.trim();
    if (siteKey.isEmpty) {
      // Debug, profile, and release: always activate with WebDebugProvider when no
      // reCAPTCHA key — skipping leaves no token and fails Auth under enforcement
      // (common with `flutter run --profile` / hosted release without dart-define).
      final dt = _webDebugToken.trim();
      final providerWeb =
          dt.isEmpty ? WebDebugProvider() : WebDebugProvider(debugToken: dt);
      debugPrint(
        '[AppCheck] Web: no RECAPTCHA_SITE_KEY — using WebDebugProvider. '
        'Register the debug token from the browser console in Firebase → App Check, '
        'or set FIREBASE_APP_CHECK_WEB_RECAPTCHA_SITE_KEY for production web.',
      );
      if (dt.isEmpty) {
        debugPrint(
          '[AppCheck] IMPORTANT: Without --dart-define=FIREBASE_APP_CHECK_WEB_DEBUG_TOKEN, '
          'a NEW UUID is generated every time you start the app. Adding the previous '
          'run\'s token in Firebase will always lag one step and keep returning HTTP 403. '
          'Fix: Firebase Console → Generate token → Save, then run with '
          '--dart-define=FIREBASE_APP_CHECK_WEB_DEBUG_TOKEN=<that exact UUID>.',
        );
      }
      await FirebaseAppCheck.instance.activate(
        providerWeb: providerWeb,
        providerAndroid: providerAndroidResolved,
        providerApple: providerAppleResolved,
      );
      await _tryWarmWebAppCheckTokenAfterActivate();
    } else {
      final kind = _webProviderKind.trim().toLowerCase();
      final providerWeb = kind == 'v3'
          ? ReCaptchaV3Provider(siteKey)
          : ReCaptchaEnterpriseProvider(siteKey);
      if (kDebugMode) {
        debugPrint('[AppCheck] web provider=$kind');
      }
      await FirebaseAppCheck.instance.activate(
        providerWeb: providerWeb,
        providerAndroid: providerAndroidResolved,
        providerApple: providerAppleResolved,
      );
      await _tryWarmWebAppCheckTokenAfterActivate();
    }
  } else {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: providerAndroidResolved,
      providerApple: providerAppleResolved,
    );
  }

  if (kDebugMode && !kIsWeb) {
    try {
      await FirebaseAppCheck.instance.getToken();
      debugPrint('[AppCheck] getToken(forceRefresh=false) ok');
    } catch (e, st) {
      debugPrint('[AppCheck] getToken failed: $e');
      debugPrintStack(stackTrace: st, label: '[AppCheck]');
    }
  }
}
