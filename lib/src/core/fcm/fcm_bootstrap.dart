import "dart:async";

import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../providers/auth_providers.dart";
import "fcm_registration.dart";

/// Registers FCM tokens when a user session is present (investor + admin apps).
class FcmBootstrap extends ConsumerStatefulWidget {
  const FcmBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FcmBootstrap> createState() => _FcmBootstrapState();
}

class _FcmBootstrapState extends ConsumerState<FcmBootstrap> {
  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<User?>>(authStateProvider, (prev, next) {
      next.whenData((user) {
        if (user != null) {
          // Defer so `users/{uid}` profile bootstrap can finish before FCM merge writes.
          unawaited(
            Future<void>.delayed(const Duration(milliseconds: 900), () async {
              if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;
              await syncFcmTokenForUser(user.uid);
            }),
          );
        } else {
          unawaited(disposeFcmTokenListener());
        }
      });
    });
    return widget.child;
  }
}
