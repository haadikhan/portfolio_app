import "package:firebase_core/firebase_core.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "firebase_options.dart";
import "src/admin/admin_app.dart";

/// Entrypoint for the Wakalat Invest admin web app (KYC review).
///
/// Run: `flutter run -d chrome -t lib/admin_main.dart`
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? initError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    initError = e;
  }
  runApp(
    ProviderScope(
      child: initError == null
          ? const WakalatAdminApp()
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
