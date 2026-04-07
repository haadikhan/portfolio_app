import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/i18n/app_translations.dart";
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
      error: (e, _) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("$e"))),
      data: (_) => context.go("/investor"),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;
    return AppScaffold(
      title: context.tr("legal_title"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 1; i <= 7; i++) ...[
              Text(
                context.tr("legal_para_$i"),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
            ],
            CheckboxListTile(
              value: accepted,
              onChanged: (v) => setState(() => accepted = v ?? false),
              title: Text(context.tr("legal_accept")),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: (!accepted || busy) ? null : _continue,
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr("continue_btn")),
            ),
          ],
        ),
      ),
    );
  }
}
