import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/compliance/risk_disclaimer_prefs.dart";
import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../core/widgets/mandatory_risk_disclaimer_strip.dart";
import "../../../providers/auth_providers.dart";

class LegalConsentScreen extends ConsumerStatefulWidget {
  const LegalConsentScreen({super.key});

  @override
  ConsumerState<LegalConsentScreen> createState() => _LegalConsentScreenState();
}

class _LegalConsentScreenState extends ConsumerState<LegalConsentScreen> {
  bool accepted = false;
  final ScrollController _scrollController = ScrollController();
  bool _reachedBottom = false;

  static const double _bottomThreshold = 48;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _evaluateScrollExtent();
      WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateScrollExtent());
    });
  }

  void _evaluateScrollExtent() {
    if (!mounted || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= _bottomThreshold) {
      setState(() => _reachedBottom = true);
    }
  }

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    if (_reachedBottom) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - _bottomThreshold) {
      setState(() => _reachedBottom = true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_reachedBottom || !accepted) return;
    await ref.read(authControllerProvider.notifier).acceptConsent();
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.hasError) {
      state.whenOrNull(
        error: (e, _) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("$e"))),
      );
      return;
    }
    await markRiskDisclaimerSeen();
    if (!mounted) return;
    context.go("/investor");
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: context.tr("legal_title"),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_reachedBottom)
                Material(
                  color: scheme.secondaryContainer.withValues(alpha: 0.5),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_downward_rounded, size: 18, color: scheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.tr("legal_scroll_hint"),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const MandatoryRiskDisclaimerStrip(),
                        const SizedBox(height: 20),
                        for (var i = 1; i <= 7; i++) ...[
                          Text(
                            context.tr("legal_para_$i"),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CheckboxListTile(
                      value: accepted,
                      onChanged: (!_reachedBottom || busy)
                          ? null
                          : (v) => setState(() => accepted = v ?? false),
                      title: Text(context.tr("legal_accept")),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: (!accepted || !_reachedBottom || busy) ? null : _continue,
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
            ],
          );
        },
      ),
    );
  }
}
