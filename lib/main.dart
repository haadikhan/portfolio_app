import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'src/app/app.dart';
import 'src/core/config/app_config.dart';
import 'src/core/fcm/fcm_bootstrap.dart';

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
          ? FcmBootstrap(
              child: WakalatInvestApp(config: AppConfig.fromEnvironment()),
            )
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
