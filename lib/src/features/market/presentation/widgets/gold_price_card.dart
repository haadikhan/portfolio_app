import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../../../core/i18n/app_translations.dart";
import "../../data/gold_units.dart";
import "../providers/kmi30_companies_providers.dart";

/// Dashboard-style card for spot gold (USD/oz) and PKR conversion (KMI30 screen only).
class GoldPriceCard extends ConsumerWidget {
  const GoldPriceCard({super.key});

  static final NumberFormat _usdPlain = NumberFormat("#,##0.00", "en_US");
  static final NumberFormat _pkr = NumberFormat.currency(
    symbol: "PKR ",
    decimalDigits: 2,
  );
  static final DateFormat _updated = DateFormat.yMMMd().add_Hm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(goldPriceStreamProvider);
    final initial = ref.watch(goldPriceInitialProvider);
    final fallback = ref.watch(goldPriceLastKnownProvider);
    final quote = live.valueOrNull ?? initial.valueOrNull ?? fallback;
    final isLoading = quote == null && (live.isLoading || initial.isLoading);
    final hasError = quote == null && (live.hasError || initial.hasError);
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;
    final pkrUnit = ref.watch(goldPkrUnitProvider);
    final pkrFactor = goldPkrDisplayFactor(pkrUnit);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push("/market/gold"),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: isLoading
            ? _Header(
                title: context.tr("gold_prices_title"),
                trailing: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : quote == null
            ? _GoldError(
                onRefresh: () {
                  ref.read(goldPriceRefreshCounterProvider.notifier).refresh();
                },
                showError: hasError,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    title: context.tr("gold_prices_title"),
                    trailing: IconButton(
                      tooltip: context.tr("gold_refresh"),
                      onPressed: () {
                        ref
                            .read(goldPriceRefreshCounterProvider.notifier)
                            .refresh();
                      },
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: scheme.primary,
                        size: 22,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<GoldPkrUnit>(
                    segments: [
                      ButtonSegment(
                        value: GoldPkrUnit.tola,
                        label: Text(context.tr("gold_unit_tola")),
                      ),
                      ButtonSegment(
                        value: GoldPkrUnit.troyOz,
                        label: Text(context.tr("gold_unit_troy_oz")),
                      ),
                    ],
                    selected: {pkrUnit},
                    onSelectionChanged: (s) => ref
                        .read(goldPkrUnitProvider.notifier)
                        .state = s.first,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr("gold_unit_hint"),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _ValueLine(
                    label: context.tr("gold_price_xau_usd"),
                    value: "USD ${_usdPlain.format(quote.xauUsd)}",
                    color: onSurface,
                  ),
                  const SizedBox(height: 4),
                  _ValueLine(
                    label: pkrUnit == GoldPkrUnit.tola
                        ? context.tr("gold_price_pkr_per_tola")
                        : context.tr("gold_price_xau_pkr"),
                    value: _pkr.format(quote.xauPkr * pkrFactor),
                    color: onSurface,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${context.tr("gold_last_updated")}: ${_updated.format(quote.timestamp.toLocal())}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.trailing});
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.monetization_on_outlined, color: scheme.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        trailing,
      ],
    );
  }
}

class _ValueLine extends StatelessWidget {
  const _ValueLine({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _GoldError extends StatelessWidget {
  const _GoldError({required this.onRefresh, required this.showError});
  final VoidCallback onRefresh;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: context.tr("gold_prices_title"),
          trailing: IconButton(
            tooltip: context.tr("gold_refresh"),
            onPressed: onRefresh,
            icon: Icon(Icons.refresh_rounded, color: scheme.primary, size: 22),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.tr("gold_unavailable"),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: showError ? scheme.error : scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
