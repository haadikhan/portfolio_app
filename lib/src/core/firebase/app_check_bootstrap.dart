import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Sideloaded release builds need the debug provider + a registered debug token.
/// Play / App Store production attestation is opt-in via dart-define.
const bool kAppCheckProductionAttestation = bool.fromEnvironment(
  'FIREBASE_APP_CHECK_USE_PRODUCTION_ATTESTATION',
  defaultValue: false,
);

Future<void> activateFirebaseAppCheckBootstrap() async {
  final AndroidProvider android;
  final AppleProvider apple;
  if (kDebugMode) {
    android = AndroidProvider.debug;
    apple = AppleProvider.debug;
  } else {
    android = kAppCheckProductionAttestation
        ? AndroidProvider.playIntegrity
        : AndroidProvider.debug;
    apple = kAppCheckProductionAttestation
        ? AppleProvider.deviceCheck
        : AppleProvider.debug;
  }
  if (kDebugMode) {
    debugPrint(
      '[AppCheck] activate android=$android apple=$apple '
      'productionAttestation=$kAppCheckProductionAttestation',
    );
  }
  await FirebaseAppCheck.instance.activate(
    androidProvider: android,
    appleProvider: apple,
  );
  if (kDebugMode) {
    try {
      await FirebaseAppCheck.instance.getToken();
      debugPrint('[AppCheck] getToken(forceRefresh=false) ok');
    } catch (e, st) {
      debugPrint('[AppCheck] getToken failed: $e');
      debugPrintStack(stackTrace: st, label: '[AppCheck]');
    }
  }
}
