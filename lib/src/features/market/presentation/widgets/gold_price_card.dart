import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../../../core/i18n/app_translations.dart";
import "../../data/gold_units.dart";
import "../../providers/kmi30_index_provider.dart";
import "../providers/kmi30_companies_providers.dart";

/// Premium two-panel header card: Gold (per tola) on the left, KMI-30 index on the right.
class GoldPriceCard extends ConsumerWidget {
  const GoldPriceCard({super.key});

  static final NumberFormat _usdFmt = NumberFormat("#,##0.00", "en_US");
  static final NumberFormat _pkrFmt =
      NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);
  static final NumberFormat _idxFmt =
      NumberFormat.decimalPatternDigits(decimalDigits: 2);
  static final DateFormat _timeFmt = DateFormat.Hm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(goldPriceStreamProvider);
    final initial = ref.watch(goldPriceInitialProvider);
    final fallback = ref.watch(goldPriceLastKnownProvider);
    final quote = live.valueOrNull ?? initial.valueOrNull ?? fallback;
    final isGoldLoading = quote == null && (live.isLoading || initial.isLoading);

    final kmi30Async = ref.watch(kmi30IndexTickProvider);
    final kmi30 = kmi30Async.valueOrNull;

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Always use tola factor — no toggle
    final tolaPkr = quote != null
        ? quote.xauPkr * goldPkrDisplayFactor(GoldPkrUnit.tola)
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.90)
              : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Gold half ─────────────────────────────────────────────
              Expanded(
                child: _GoldHalf(
                  isLoading: isGoldLoading,
                  tolaPkr: tolaPkr,
                  usdFmt: _usdFmt,
                  pkrFmt: _pkrFmt,
                  timeFmt: _timeFmt,
                  usdValue: quote?.xauUsd,
                  timestamp: quote?.timestamp,
                  hasError: quote == null &&
                      (live.hasError || initial.hasError),
                  onRefresh: () =>
                      ref.read(goldPriceRefreshCounterProvider.notifier).refresh(),
                  onTap: () => context.push("/market/gold"),
                ),
              ),

              // ── Vertical divider ──────────────────────────────────────
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),

              // ── KMI-30 half ───────────────────────────────────────────
              Expanded(
                child: _Kmi30Half(
                  tick: kmi30,
                  isLoading: kmi30Async.isLoading && kmi30 == null,
                  idxFmt: _idxFmt,
                  onTap: () => context.push("/market/kmi30-companies"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Gold panel ─────────────────────────────────────────────────────────────

class _GoldHalf extends StatelessWidget {
  const _GoldHalf({
    required this.isLoading,
    required this.tolaPkr,
    required this.usdFmt,
    required this.pkrFmt,
    required this.timeFmt,
    required this.usdValue,
    required this.timestamp,
    required this.hasError,
    required this.onRefresh,
    required this.onTap,
  });

  final bool isLoading;
  final double? tolaPkr;
  final NumberFormat usdFmt;
  final NumberFormat pkrFmt;
  final DateFormat timeFmt;
  final double? usdValue;
  final DateTime? timestamp;
  final bool hasError;
  final VoidCallback onRefresh;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label row
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.toll_rounded,
                    size: 16,
                    color: Color(0xFFB8860B),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  context.tr("gold_prices_title"),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onRefresh,
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isLoading) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ] else if (tolaPkr == null) ...[
              Text(
                hasError
                    ? context.tr("gold_unavailable")
                    : context.tr("gold_unavailable"),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              Text(
                pkrFmt.format(tolaPkr),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                context.tr("gold_price_pkr_per_tola"),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "USD ${usdFmt.format(usdValue ?? 0)}",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              if (timestamp != null) ...[
                const SizedBox(height: 2),
                Text(
                  timeFmt.format(timestamp!.toLocal()),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ── KMI-30 panel ───────────────────────────────────────────────────────────

class _Kmi30Half extends StatelessWidget {
  const _Kmi30Half({
    required this.tick,
    required this.isLoading,
    required this.idxFmt,
    required this.onTap,
  });

  final dynamic tick; // Kmi30IndexTick?
  final bool isLoading;
  final NumberFormat idxFmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    Color changeColor;
    String indexStr;
    String changeStr;

    if (tick != null) {
      final pct = (tick.changePercent as double);
      final abs = (tick.changeAbsolute as double);
      changeColor = pct > 0
          ? Colors.green.shade600
          : pct < 0
              ? Colors.red.shade600
              : scheme.onSurfaceVariant;
      indexStr = idxFmt.format(tick.currentValue as double);
      final sign = abs >= 0 ? "+" : "";
      final pctSign = pct >= 0 ? "+" : "";
      changeStr =
          "$pctSign${pct.toStringAsFixed(2)}%  ($sign${idxFmt.format(abs)})";
    } else {
      changeColor = scheme.onSurfaceVariant;
      indexStr = "--";
      changeStr = "--";
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label row
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.show_chart_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  "KMI-30",
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isLoading) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ] else ...[
              Text(
                indexStr,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                context.tr("market_day_change"),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                changeStr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: changeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
