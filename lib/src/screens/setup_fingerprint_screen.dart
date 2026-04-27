import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../core/i18n/app_translations.dart";
import "../providers/biometric_providers.dart";

class SetupFingerprintScreen extends ConsumerWidget {
  const SetupFingerprintScreen({super.key, this.email});

  final String? email;

  Future<void> _enableFingerprint(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(biometricControllerProvider.notifier)
        .enableForCurrentUser(fallbackEmail: email);
    if (!context.mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("biometric_enabled_success"))),
      );
      context.go("/");
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr("biometric_enable_failed"))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilityAsync = ref.watch(biometricCapabilityProvider);
    final loading = ref.watch(biometricControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr("setup_fingerprint_title"))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.fingerprint_rounded, size: 72),
            const SizedBox(height: 16),
            Text(
              context.tr("setup_fingerprint_heading"),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              context.tr("setup_fingerprint_subtitle"),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            capabilityAsync.when(
              data: (capability) {
                if (capability.isAvailable) {
                  return const SizedBox.shrink();
                }
                return Text(
                  context.tr("fingerprint_not_setup"),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.orange),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Text(
                context.tr("fingerprint_not_setup"),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.orange),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: loading
                  ? null
                  : () => _enableFingerprint(context, ref),
              icon: const Icon(Icons.fingerprint_rounded),
              label: loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr("enable_fingerprint_button")),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: loading ? null : () => context.go("/"),
              child: Text(context.tr("skip_for_now")),
            ),
          ],
        ),
      ),
    );
  }
}
