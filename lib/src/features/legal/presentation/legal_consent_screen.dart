import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/widgets/app_scaffold.dart";
import "../../../providers/auth_providers.dart";

class LegalConsentScreen extends ConsumerStatefulWidget {
  const LegalConsentScreen({super.key});

  @override
  ConsumerState<LegalConsentScreen> createState() => _LegalConsentScreenState();
}

class _LegalConsentScreenState extends ConsumerState<LegalConsentScreen> {
  bool accepted = false;

  Future<void> _continue() async {
    await ref.read(authControllerProvider.notifier).acceptConsent();
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    state.whenOrNull(
      error: (e, _) =>
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e"))),
      data: (_) => context.go("/investor"),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;
    return AppScaffold(
      title: "Legal & Disclaimer",
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("This is a private investment tracking platform."),
            const Text("Returns are not guaranteed."),
            const Text("Past performance does not guarantee future results."),
            const Text("We follow compliance best practices for KYC and consent."),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: accepted,
              onChanged: (v) => setState(() => accepted = v ?? false),
              title: const Text("I understand and accept the disclaimer."),
            ),
            FilledButton(
              onPressed: (!accepted || busy) ? null : _continue,
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Continue"),
            ),
          ],
        ),
      ),
    );
  }
}
