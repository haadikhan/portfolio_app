import 'package:flutter/foundation.dart';

import 'app_check_bootstrap.dart';

/// Configures Firebase Phone Auth on Android.
///
/// We rely on Play Integrity (Firebase's default) for phone verification.
/// Both SHA-1 and SHA-256 debug fingerprints are registered in the Firebase
/// Console, so Play Integrity works for debug/sideloaded builds.
///
/// forceRecaptchaFlow is intentionally NOT set here — forcing reCAPTCHA opens
/// a Chrome Custom Tab that fails to redirect back to the app on most devices,
/// leaving the OTP screen completely frozen (no callback ever fires).
///
/// When [kAppCheckProductionAttestation] is true (Play Store release builds),
/// no extra setup is needed — Firebase's default routing already uses Play
/// Integrity for both App Check and phone verification.
Future<void> configureFirebaseAndroidPhoneVerification() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android) return;

  if (kDebugMode) {
    debugPrint(
      '[FirebaseAuth][Android] Phone verification using Play Integrity '
      '(forceRecaptchaFlow not set — SHA fingerprints registered in Console)',
    );
  }
}
