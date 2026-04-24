import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_error_dialog.dart";
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
    if (!accepted) return;
    await ref.read(authControllerProvider.notifier).acceptConsent();
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.hasError && state.error != null) {
      await showAppErrorDialog(context, state.error!);
      return;
    }
    if (!mounted) return;
    context.go("/investor");
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;
    final consentAccepted =
        ref.watch(consentAcceptedProvider).valueOrNull == true;

    return AppScaffold(
      title: context.tr("legal_title"),
      body: consentAccepted
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr("legal_summary_title"),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(context.tr("legal_summary_subtitle")),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SummaryPoint(text: context.tr("legal_summary_point_1")),
                const SizedBox(height: 10),
                _SummaryPoint(text: context.tr("legal_summary_point_2")),
                const SizedBox(height: 10),
                _SummaryPoint(text: context.tr("legal_summary_point_3")),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        context.tr("legal_scroll_hint"),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (var i = 1; i <= 5; i++) ...[
                        Text(
                          context.tr("legal_para_$i"),
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.45),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CheckboxListTile(
                        value: accepted,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => accepted = v ?? false),
                        title: Text(context.tr("legal_accept")),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: (!accepted || busy) ? null : _continue,
                        child: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(context.tr("continue_btn")),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryPoint extends StatelessWidget {
  const _SummaryPoint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle_outline_rounded, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
