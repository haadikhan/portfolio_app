import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "package:portfolio_app/src/core/i18n/app_translations.dart";
import "package:portfolio_app/src/features/investment/data/allocation_money_market.dart";
import "package:portfolio_app/src/features/investment/domain/five_market_models.dart";
import "package:portfolio_app/src/features/investment/presentation/market_detail/market_detail_providers.dart";
import "package:portfolio_app/src/features/investment/presentation/market_detail/market_detail_shell.dart";
import "package:portfolio_app/src/features/investment/providers/five_market_providers.dart";
import "package:portfolio_app/src/features/market/data/models/gold_price_quote.dart";
import "package:portfolio_app/src/features/market/presentation/providers/kmi30_companies_providers.dart";
import "package:portfolio_app/src/providers/wallet_providers.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);
final _usdFmt = NumberFormat.currency(symbol: "USD ", decimalDigits: 2);
final _tolaFmt = NumberFormat.decimalPatternDigits(decimalDigits: 4);

const _amberGold = Color(0xFFF5A623);

/// Gold sleeve detail: spot price, holdings in Tolas, and daily performance.
class GoldMarketDetailScreen extends ConsumerStatefulWidget {
  const GoldMarketDetailScreen({super.key});

  @override
  ConsumerState<GoldMarketDetailScreen> createState() =>
      _GoldMarketDetailScreenState();
}

class _GoldMarketDetailScreenState extends ConsumerState<GoldMarketDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(goldMarketQuoteProvider) == null) {
        ref.read(goldPriceRefreshCounterProvider.notifier).refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final live = ref.watch(goldPriceStreamProvider);
    final initial = ref.watch(goldPriceInitialProvider);
    final quote = ref.watch(goldMarketQuoteProvider);
    final pricePerTola = ref.watch(goldPricePerTolaProvider);
    final dailyResult = ref.watch(fiveMarketDailyResultProvider);
    final wallet = ref.watch(userWalletStreamProvider).valueOrNull;
    final config = ref.watch(fiveMarketConfigProvider).valueOrNull;
    final allocationBase = allocationTotalFromWallet(wallet);
    final slice = dailyResult?.gold;
    final isPriceLoading =
        quote == null && (live.isLoading || initial.isLoading);
    final isPriceError =
        quote == null && !isPriceLoading && (live.hasError || initial.hasError);

    return MarketDetailShell(
      title: "Gold Market",
      accentColor: _amberGold,
      backgroundImageProvider: const NetworkImage(
        "https://images.unsplash.com/photo-1610375461246-83df859d849d?w=800&q=60",
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PriceHeroCard(
              scheme: scheme,
              quote: quote,
              pricePerTola: pricePerTola,
              isLoading: isPriceLoading,
              isError: isPriceError,
              onRetry: () =>
                  ref.read(goldPriceRefreshCounterProvider.notifier).refresh(),
            ),
            const SizedBox(height: 16),
            _HoldingsCard(
              scheme: scheme,
              allocatedPkr: slice?.allocatedPkr ??
                  (config != null
                      ? allocationAmountFromTotal(
                          allocationBase,
                          config.allocations.gold,
                        )
                      : null),
              pricePerTola: pricePerTola,
            ),
            const SizedBox(height: 16),
            if (dailyResult == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              _PerformanceCard(
                scheme: scheme,
                slice: slice!,
                goldAllocationPercent: config?.allocations.gold ?? 5,
              ),
            const SizedBox(height: 16),
            const _AboutGoldSleeveCard(),
          ],
        ),
      ),
    );
  }
}

class _PriceHeroCard extends StatelessWidget {
  const _PriceHeroCard({
    required this.scheme,
    required this.quote,
    required this.pricePerTola,
    required this.isLoading,
    required this.isError,
    required this.onRetry,
  });

  final ColorScheme scheme;
  final GoldPriceQuote? quote;
  final double? pricePerTola;
  final bool isLoading;
  final bool isError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget valueChild;
    if (isLoading) {
      valueChild = const LinearProgressIndicator();
    } else {
      final price = pricePerTola;
      if (price == null || price <= 0) {
        valueChild = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr("mkt_price_unavailable"),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (isError) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onRetry,
                child: Text(context.tr("gold_refresh")),
              ),
            ],
          ],
        );
      } else {
        valueChild = Text(
          "${_money.format(price)} / Tola",
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: _amberGold,
          ),
        );
      }
    }

    return Card(
      color: _amberGold.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr("mkt_gold_price_today"),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            valueChild,
            if (quote != null && !isLoading) ...[
              const SizedBox(height: 10),
              _GoldStatRow(
                label: "USD / troy oz",
                value: _usdFmt.format(quote!.xauUsd),
                scheme: scheme,
              ),
              if (quote!.changePercent != 0) ...[
                _GoldStatRow(
                  label: context.tr("mkt_change"),
                  value:
                      "${quote!.changePercent >= 0 ? "+" : ""}${quote!.changePercent.toStringAsFixed(2)}%",
                  scheme: scheme,
                  valueColor: quote!.changePercent > 0
                      ? scheme.primary
                      : quote!.changePercent < 0
                          ? scheme.error
                          : null,
                ),
              ],
            ],
            const SizedBox(height: 8),
            Text(
              quote != null
                  ? context.trParams(
                      "mkt_gold_source_from",
                      {"source": quote!.source},
                    )
                  : context.tr("mkt_gold_source_note"),
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

class _HoldingsCard extends StatelessWidget {
  const _HoldingsCard({
    required this.scheme,
    required this.allocatedPkr,
    required this.pricePerTola,
  });

  final ColorScheme scheme;
  final double? allocatedPkr;
  final double? pricePerTola;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = pricePerTola;
    final allocated = allocatedPkr;
    final hasTola = price != null && price > 0 && allocated != null;
    final tolaText = hasTola
        ? "${_tolaFmt.format(allocated / price)} tola"
        : "—";

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.diamond_outlined, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  context.tr("mkt_gold_holdings_title"),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _GoldStatRow(
              label: context.tr("mkt_gold_allocated_pkr"),
              value: allocated != null ? _money.format(allocated) : "—",
              scheme: scheme,
            ),
            _GoldStatRow(
              label: context.tr("mkt_gold_equivalent_tola"),
              value: tolaText,
              scheme: scheme,
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({
    required this.scheme,
    required this.slice,
    required this.goldAllocationPercent,
  });

  final ColorScheme scheme;
  final MarketSliceResult slice;
  final double goldAllocationPercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profit = slice.profitPkr;
    final profitColor = profit > 0
        ? scheme.primary
        : profit < 0
            ? scheme.error
            : scheme.onSurfaceVariant;
    final change = slice.changePercent;
    final changeColor = change > 0
        ? scheme.primary
        : change < 0
            ? scheme.error
            : scheme.onSurfaceVariant;
    final changeText = change >= 0
        ? "+${change.toStringAsFixed(2)}%"
        : "${change.toStringAsFixed(2)}%";
    final statusKey = _statusTranslationKey(slice.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_rounded, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  context.tr("mkt_todays_return"),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _GoldStatRow(
              label: context.tr("mkt_profit_pkr"),
              value: "${profit >= 0 ? "+" : ""}${_money.format(profit)}",
              scheme: scheme,
              valueColor: profitColor,
            ),
            _GoldStatRow(
              label: context.tr("mkt_change"),
              value: changeText,
              scheme: scheme,
              valueColor: changeColor,
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
            _GoldStatRow(
              label: context.tr("mkt_allocation_pct"),
              value:
                  "${goldAllocationPercent.toStringAsFixed(0)}% of portfolio",
              scheme: scheme,
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutGoldSleeveCard extends StatelessWidget {
  const _AboutGoldSleeveCard();

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
            Text(
              "Your portfolio's gold allocation tracks international spot "
              "gold prices converted to PKR. Gold acts as a hedge against "
              "inflation and currency risk. Returns vary daily based on "
              "XAU/USD and PKR/USD rates.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
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

class _GoldStatRow extends StatelessWidget {
  const _GoldStatRow({
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
