// Entry point for the admin web app (see class doc on main below).
import "package:firebase_core/firebase_core.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "firebase_options.dart";
import "src/admin/admin_app.dart";
import "src/core/firebase/app_check_bootstrap.dart";
import "src/core/firebase/firebase_auth_phone_bootstrap.dart";
import "src/core/fcm/fcm_bootstrap.dart";

/// Entrypoint for the ISC-WAI admin web app (KYC review).
///
/// Run: `flutter run -d chrome -t lib/admin_main.dart`
///
/// Uses the same App Check bootstrap as [lib/main.dart] so Firebase Auth stays
/// valid when App Check enforcement is enabled for `identitytoolkit`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? initError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await configureFirebaseAndroidPhoneVerification();
    await activateFirebaseAppCheckBootstrap();
  } catch (e) {
    initError = e;
  }
  runApp(
    ProviderScope(
      child: initError == null
          ? const FcmBootstrap(child: WakalatAdminApp())
          : MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      "Firebase initialization failed.\n"
                      "Please verify your Firebase project settings.\n\n"
                      "Error: $initError",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
    ),
  );
}
