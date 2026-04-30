import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'app_check_bootstrap.dart';

/// Ensures Firebase Phone Auth on Android prefers reCAPTCHA over Play Integrity when
/// the app is sideloaded or not using Play production attestation.
///
/// Without this, the SDK logs `No Recaptcha Enterprise siteKey` and falls through to a
/// Play Integrity token path that commonly returns **17028 Invalid app info in
/// play_integrity_token** on debug/non-Play-signed installs—even when App Check works.
///
/// When [kAppCheckProductionAttestation] is true (release builds meant for Play with
/// attestation-only App Check), we leave Firebase's default routing so Integrity can
/// be used for phone flows as well.
Future<void> configureFirebaseAndroidPhoneVerification() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android) return;

  final bool forceRecaptcha = kDebugMode || !kAppCheckProductionAttestation;
  try {
    if (forceRecaptcha) {
      await FirebaseAuth.instance.setSettings(forceRecaptchaFlow: true);
      if (kDebugMode) {
        debugPrint(
          '[FirebaseAuth][Android] Phone Auth: forceRecaptchaFlow=true '
          '(matches sideload/non–Play Integrity attestation path)',
        );
      }
    }

    await FirebaseAuth.instance.initializeRecaptchaConfig();

    if (kDebugMode) {
      debugPrint('[FirebaseAuth][Android] initializeRecaptchaConfig finished');
    }
  } catch (e, st) {
    // Console may still lack reCAPTCHA Enterprise linkage; OTP will fail later with a
    // clear message—but the app must keep starting.
    if (kDebugMode) {
      debugPrint('[FirebaseAuth][Android] phone verification bootstrap failed: $e');
      debugPrintStack(stackTrace: st, label: '[FirebaseAuth][Android]');
    }
  }
}
