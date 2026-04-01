import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../providers/auth_providers.dart";

class ConsentGateScreen extends ConsumerWidget {
  const ConsentGateScreen({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consentAsync = ref.watch(consentAcceptedProvider);
    return consentAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text("Error: $e"))),
      data: (accepted) {
        if (accepted) return child;
        return Scaffold(
          appBar: AppBar(title: const Text("Consent required")),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "You must accept legal and risk consent before using investor features.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.go("/legal"),
                      child: const Text("Open legal consent"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
