import 'package:flutter/foundation.dart';

import 'app_check_bootstrap.dart';

/// Configures Firebase Phone Auth on Android.
///
/// Firebase Phone Auth uses Play Integrity (via App Check) to verify the app's
/// identity before allowing OTP dispatch.  For this to work:
///
///   1. Both the DEBUG and RELEASE SHA-1 fingerprints must be added in
///      Firebase Console → Project Settings → Android app (com.isc.wai)
///      → SHA certificate fingerprints.
///
///      Debug  SHA-1  : 34:84:4A:31:DB:5E:3E:58:45:73:9C:8B:9B:24:89:D3:56:71:F5:ED
///      Release SHA-1 : EB:17:AF:B1:E8:DE:48:2D:A6:79:10:D9:27:66:10:CE:AD:AA:84:2D
///      Debug  SHA-256: 4D:15:E6:93:4D:C2:3C:B6:16:4E:50:9D:E3:3B:9C:17:EE:B7:9E:D8:40:C8:A6:04:54:2F:F3:9E:DD:20:D5:D7
///      Release SHA-256: 4D:4B:E4:2B:30:ED:5D:8D:A3:3D:CD:C7:3F:19:29:08:33:EA:3A:4E:7B:62:52:F8:0A:29:CE:1B:38:9E:1C:B3
///
///   2. After adding fingerprints, re-download google-services.json from
///      Firebase Console and replace android/app/google-services.json.
///
///   3. Release builds use AndroidPlayIntegrityProvider (App Check).
///      Debug builds use AndroidDebugProvider — register the token printed
///      to logcat in Firebase Console → App Check → Manage debug tokens if
///      enforcement is enabled.
///
/// forceRecaptchaFlow is intentionally NOT set — it opens a Chrome Custom Tab
/// that fails to redirect back to the app on most devices, leaving the OTP
/// screen frozen with no callback.
Future<void> configureFirebaseAndroidPhoneVerification() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android) return;

  debugPrint(
    '[FirebaseAuth][Android] Phone verification — '
    'App Check provider: ${kDebugMode ? "AndroidDebugProvider" : kAppCheckProductionAttestation ? "AndroidPlayIntegrityProvider" : "AndroidDebugProvider (forced via dart-define)"} '
    '| Make sure both SHA-1 fingerprints are registered in Firebase Console.',
  );
}
