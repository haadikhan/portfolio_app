import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "package:portfolio_app/src/core/i18n/app_translations.dart";
import "package:portfolio_app/src/features/investment/domain/five_market_models.dart";
import "package:portfolio_app/src/features/investment/presentation/market_detail/market_detail_shell.dart";
import "package:portfolio_app/src/features/investment/providers/five_market_providers.dart";
import "package:portfolio_app/src/providers/wallet_providers.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);

const _teal = Color(0xFF004D40);

/// Debt / fixed-income sleeve detail: annual rate breakdown and allocation.
class DebtMarketDetailScreen extends ConsumerWidget {
  const DebtMarketDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dailyResult = ref.watch(fiveMarketDailyResultProvider);
    ref.watch(userWalletStreamProvider);
    final config = ref.watch(fiveMarketConfigProvider).valueOrNull;
    final rate = config?.rates.debtAnnualPercent ??
        FiveMarketConfig.defaults.rates.debtAnnualPercent;
    final debtAllocationPercent = config?.allocations.debt ?? 25;

    return MarketDetailShell(
      title: "Debt Market",
      accentColor: _teal,
      backgroundImageProvider: const NetworkImage(
        "https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=800&q=60",
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DebtRateHeroCard(scheme: scheme, rate: rate),
            const SizedBox(height: 12),
            if (dailyResult == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              _DebtHoldingsCard(
                scheme: scheme,
                slice: dailyResult.debt,
                rate: rate,
                debtAllocationPercent: debtAllocationPercent,
              ),
            const SizedBox(height: 12),
            const _AboutDebtSleeveCard(),
          ],
        ),
      ),
    );
  }
}

class _DebtRateHeroCard extends StatelessWidget {
  const _DebtRateHeroCard({
    required this.scheme,
    required this.rate,
  });

  final ColorScheme scheme;
  final double rate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: _teal.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_rounded, color: _teal),
                const SizedBox(width: 8),
                Text(
                  context.tr("mkt_debt_rate_title"),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Text(
                    "${rate.toStringAsFixed(1)}%",
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _teal,
                    ),
                  ),
                  Text(
                    context.tr("mkt_debt_per_annum"),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                Expanded(
                  child: _FrequencyColumn(
                    label: context.tr("mkt_debt_monthly"),
                    value: "${(rate / 12).toStringAsFixed(2)}%",
                    subLabel: context.tr("mkt_debt_per_month"),
                    scheme: scheme,
                  ),
                ),
                Expanded(
                  child: _FrequencyColumn(
                    label: context.tr("mkt_debt_weekly"),
                    value: "${(rate / 52).toStringAsFixed(3)}%",
                    subLabel: context.tr("mkt_debt_per_week"),
                    scheme: scheme,
                  ),
                ),
                Expanded(
                  child: _FrequencyColumn(
                    label: context.tr("mkt_debt_daily"),
                    value: "${(rate / 365).toStringAsFixed(4)}%",
                    subLabel: context.tr("mkt_debt_per_day"),
                    scheme: scheme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FrequencyColumn extends StatelessWidget {
  const _FrequencyColumn({
    required this.label,
    required this.value,
    required this.subLabel,
    required this.scheme,
  });

  final String label;
  final String value;
  final String subLabel;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
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

class _DebtHoldingsCard extends StatelessWidget {
  const _DebtHoldingsCard({
    required this.scheme,
    required this.slice,
    required this.rate,
    required this.debtAllocationPercent,
  });

  final ColorScheme scheme;
  final MarketSliceResult slice;
  final double rate;
  final double debtAllocationPercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profit = slice.profitPkr;
    final profitColor = profit > 0
        ? scheme.primary
        : profit < 0
            ? scheme.error
            : scheme.onSurfaceVariant;
    final monthlyReturn = slice.allocatedPkr * rate / 100 / 12;
    final statusKey = _statusTranslationKey(slice.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  context.tr("mkt_debt_holdings_title"),
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
              label: context.tr("mkt_debt_implied_monthly"),
              value: "PKR ${monthlyReturn.toStringAsFixed(2)}",
              scheme: scheme,
              valueColor: _teal,
            ),
            _StatRow(
              label: context.tr("mkt_todays_profit"),
              value: "${profit >= 0 ? "+" : ""}${_money.format(profit)}",
              scheme: scheme,
              valueColor: profitColor,
            ),
            _StatRow(
              label: context.tr("mkt_annual_rate"),
              value: "${rate.toStringAsFixed(1)}% p.a.",
              scheme: scheme,
              valueColor: _teal,
            ),
            _StatRow(
              label: context.tr("mkt_allocation_pct"),
              value: "${debtAllocationPercent.toStringAsFixed(0)}% of portfolio",
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
      ),
    );
  }
}

class _AboutDebtSleeveCard extends StatelessWidget {
  const _AboutDebtSleeveCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    Icons.assured_workload_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  label: const Text("Govt Bonds"),
                  labelStyle: theme.textTheme.labelSmall,
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  avatar: Icon(
                    Icons.security_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  label: const Text("T-Bills"),
                  labelStyle: theme.textTheme.labelSmall,
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  avatar: Icon(
                    Icons.mosque_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  label: const Text("Sukuk"),
                  labelStyle: theme.textTheme.labelSmall,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "The debt sleeve invests in Pakistan government fixed-income "
              "instruments — including Treasury Bills, Pakistan Investment "
              "Bonds (PIBs), and Shariah-compliant Sukuk. These instruments "
              "offer stable, predictable returns backed by the Government of "
              "Pakistan, providing capital preservation and steady income.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: _teal, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Government-backed • Capital preservation focus",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _teal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
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
