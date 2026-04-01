import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../providers/auth_providers.dart";

class AuthGateScreen extends ConsumerWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          Scaffold(body: Center(child: Text("Auth error: $error"))),
      data: (user) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          if (user == null) {
            context.go("/login");
          } else {
            // Investor entry point after login.
            context.go("/investor");
          }
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
