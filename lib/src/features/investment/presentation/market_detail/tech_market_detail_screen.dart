import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "package:portfolio_app/src/core/i18n/app_translations.dart";
import "package:portfolio_app/src/core/theme/app_colors.dart";
import "package:portfolio_app/src/features/investment/domain/five_market_models.dart";
import "package:portfolio_app/src/features/investment/domain/market_sleeve_balance.dart";
import "package:portfolio_app/src/features/investment/presentation/market_detail/market_detail_shell.dart";
import "package:portfolio_app/src/features/investment/presentation/market_detail/sleeve_report_download.dart";
import "package:portfolio_app/src/features/investment/providers/five_market_providers.dart";
import "package:portfolio_app/src/providers/wallet_providers.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);

const _indigo = Color(0xFF311B92);
const _cyanAccent = Color(0xFF00BCD4);

/// Tech & innovation sleeve detail: benchmark/target rates and allocation.
class TechMarketDetailScreen extends ConsumerWidget {
  const TechMarketDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dailyResult = ref.watch(fiveMarketDailyResultProvider);
    ref.watch(userWalletStreamProvider);
    final config = ref.watch(fiveMarketConfigProvider).valueOrNull;
    final rates = config?.rates ?? FiveMarketConfig.defaults.rates;
    final benchmarkRate = rates.techBenchmarkAnnualPercent;
    final targetRate = rates.techTargetAnnualPercent;
    final techAllocationPercent = config?.allocations.tech ?? 25;

    return MarketDetailShell(
      title: "Tech & Innovation Market",
      accentColor: _indigo,
      backgroundImageProvider: const NetworkImage(
        "https://images.unsplash.com/photo-1620712943543-bcc4688e7485?w=800&q=60",
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _TechRateHeroCard(
            scheme: scheme,
            benchmarkRate: benchmarkRate,
            targetRate: targetRate,
          ),
          const SizedBox(height: 14),
          if (dailyResult == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            _TechHoldingsCard(
              scheme: scheme,
              slice: dailyResult.tech,
              techAllocationPercent: techAllocationPercent,
            ),
          const SizedBox(height: 14),
          const _AboutTechSleeveCard(),
          const SizedBox(height: 14),
          const _SleeveHistoryCard(
            accentColor: _indigo,
            sleeve: MarketSleeve.tech,
            reportTitle: "Tech & Innovation Market",
            pdfTitleKey: "sleeve_report_pdf_title_tech",
          ),
        ],
      ),
    );
  }
}

class _TechRateHeroCard extends StatelessWidget {
  const _TechRateHeroCard({
    required this.scheme,
    required this.benchmarkRate,
    required this.targetRate,
  });

  final ColorScheme scheme;
  final double benchmarkRate;
  final double targetRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dailyLow = benchmarkRate / 365;
    final dailyHigh = targetRate / 365;

    return _GlassCard(
      accentColor: _indigo,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _indigo.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.rocket_launch_rounded, color: _indigo),
                const SizedBox(width: 8),
                Text(
                  context.tr("mkt_tech_rate_title"),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _RateBox(
                      title: context.tr("mkt_tech_benchmark"),
                      rateText: "${benchmarkRate.toStringAsFixed(0)}% p.a.",
                      rateColor: _indigo,
                      subLabel: context.tr("mkt_tech_floor_label"),
                      scheme: scheme,
                    ),
                  ),
                  const SizedBox(height: 60, child: VerticalDivider(width: 24)),
                  Expanded(
                    child: _RateBox(
                      title: context.tr("mkt_tech_target"),
                      rateText: "${targetRate.toStringAsFixed(0)}% p.a.",
                      rateColor: _cyanAccent,
                      subLabel: context.tr("mkt_tech_goal_label"),
                      scheme: scheme,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Daily accrual: ${dailyLow.toStringAsFixed(4)}% – "
              "${dailyHigh.toStringAsFixed(4)}% per day",
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RateBox extends StatelessWidget {
  const _RateBox({
    required this.title,
    required this.rateText,
    required this.rateColor,
    required this.subLabel,
    required this.scheme,
  });

  final String title;
  final String rateText;
  final Color rateColor;
  final String subLabel;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          rateText,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: rateColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subLabel,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TechHoldingsCard extends StatelessWidget {
  const _TechHoldingsCard({
    required this.scheme,
    required this.slice,
    required this.techAllocationPercent,
  });

  final ColorScheme scheme;
  final MarketSliceResult slice;
  final double techAllocationPercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profit = slice.profitPkr;
    final profitColor = profit > 0
        ? scheme.primary
        : profit < 0
        ? scheme.error
        : scheme.onSurfaceVariant;
    final annual = slice.annualPercent;
    final change = slice.changePercent;
    final String changeText;
    final Color? changeColor;
    if (annual != null) {
      changeText = "${annual.toStringAsFixed(1)}% p.a. (accrued rate)";
      changeColor = scheme.onSurfaceVariant;
    } else {
      changeText = change >= 0
          ? "+${change.toStringAsFixed(2)}%"
          : "${change.toStringAsFixed(2)}%";
      changeColor = change > 0
          ? scheme.primary
          : change < 0
          ? scheme.error
          : scheme.onSurfaceVariant;
    }
    final statusKey = _statusTranslationKey(slice.status);

    return _GlassCard(
      accentColor: _indigo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.memory_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                context.tr("mkt_tech_holdings_title"),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: "Allocated (PKR)",
            value: _money.format(slice.allocatedPkr),
            scheme: scheme,
          ),
          _StatRow(
            label: context.tr("mkt_todays_profit"),
            value: "${profit >= 0 ? "+" : ""}${_money.format(profit)}",
            scheme: scheme,
            valueColor: profitColor,
          ),
          _StatRow(
            label: context.tr("mkt_change"),
            value: changeText,
            scheme: scheme,
            valueColor: changeColor,
          ),
          _StatRow(
            label: context.tr("mkt_allocation_pct"),
            value: "${techAllocationPercent.toStringAsFixed(0)}% of portfolio",
            scheme: scheme,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    context.tr("mkt_status"),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        context.tr(statusKey),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutTechSleeveCard extends StatelessWidget {
  const _AboutTechSleeveCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return _GlassCard(
      accentColor: _indigo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                context.tr("mkt_about_sleeve"),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: Icon(
                  Icons.smart_toy_outlined,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                label: const Text("AI & Robotics"),
                labelStyle: theme.textTheme.labelSmall,
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                avatar: Icon(
                  Icons.biotech_outlined,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                label: const Text("Deep Tech"),
                labelStyle: theme.textTheme.labelSmall,
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                avatar: Icon(
                  Icons.language_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                label: const Text("Global Tech"),
                labelStyle: theme.textTheme.labelSmall,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "The tech sleeve captures global technology and innovation "
            "themes — including artificial intelligence, robotics, "
            "semiconductors, and emerging deep-tech sectors. Returns are "
            "benchmarked against world-class tech indices with an "
            "aggressive performance target, making this the highest-growth "
            "sleeve in your portfolio.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SleeveHistoryCard extends ConsumerWidget {
  const _SleeveHistoryCard({
    required this.accentColor,
    required this.sleeve,
    required this.reportTitle,
    required this.pdfTitleKey,
  });

  final Color accentColor;
  final MarketSleeve sleeve;
  final String reportTitle;
  final String pdfTitleKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    return _GlassCard(
      accentColor: accentColor,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: accentColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr("sleeve_report_history_card_title"),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr("sleeve_report_history_card_subtitle"),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => openSleeveReportDownload(
              context: context,
              ref: ref,
              sleeve: sleeve,
              reportTitle: reportTitle,
              pdfTitle: context.tr(pdfTitleKey),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Text(context.tr("sleeve_report_history_btn")),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.accentColor});
  final Widget child;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (accentColor ?? scheme.primary).withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

String _statusTranslationKey(MarketSliceStatus status) {
  return switch (status) {
    MarketSliceStatus.live => "five_market_status_live",
    MarketSliceStatus.realized => "five_market_status_realized",
    MarketSliceStatus.closed => "five_market_status_closed",
    MarketSliceStatus.nonTradingDay => "five_market_status_non_trading",
  };
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.scheme,
    this.valueColor,
  });

  final String label;
  final String value;
  final ColorScheme scheme;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor ?? scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
