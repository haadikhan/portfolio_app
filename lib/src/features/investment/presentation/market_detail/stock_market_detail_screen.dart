import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "package:portfolio_app/src/core/i18n/app_translations.dart";
import "package:portfolio_app/src/features/investment/domain/five_market_models.dart";
import "package:portfolio_app/src/features/investment/presentation/five_market_daily_providers.dart";
import "package:portfolio_app/src/features/investment/presentation/market_detail/market_detail_shell.dart";
import "package:portfolio_app/src/features/investment/providers/five_market_providers.dart";
import "package:portfolio_app/src/features/investment/providers/kmi30_company_allocation_provider.dart";
import "package:portfolio_app/src/features/market/data/models/kmi30_bar.dart";
import "package:portfolio_app/src/features/market/data/models/kmi30_index_tick.dart";
import "package:portfolio_app/src/features/market/presentation/widgets/kmi30_line_chart.dart";
import "package:portfolio_app/src/features/market/providers/kmi30_index_provider.dart";
import "package:portfolio_app/src/providers/wallet_providers.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);
final _indexFmt = NumberFormat.decimalPatternDigits(decimalDigits: 2);

const _psxGreen = Color(0xFF1B5E20);

/// Stock / KMI-30 sleeve detail: live index, chart, and allocation performance.
class StockMarketDetailScreen extends ConsumerWidget {
  const StockMarketDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final indexTick = ref.watch(kmi30IndexTickProvider);
    final klinesAsync = ref.watch(kmi30IndexDailyKlinesProvider);
    final dailyResult = ref.watch(fiveMarketDailyResultProvider);
    ref.watch(userWalletStreamProvider);
    final config = ref.watch(fiveMarketConfigProvider).valueOrNull;
    final slice = dailyResult?.stock;

    return MarketDetailShell(
      title: "Stock Market (KMI-30)",
      accentColor: _psxGreen,
      backgroundImageProvider: const NetworkImage(
        "https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=800&q=60",
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _Kmi30LiveIndexCard(
              scheme: scheme,
              indexTick: indexTick,
              klinesAsync: klinesAsync,
            ),
          const SizedBox(height: 14),
          if (dailyResult == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              _StockHoldingsCard(
                scheme: scheme,
                slice: slice!,
                stockAllocationPercent: config?.allocations.stock ?? 40,
              ),
          const SizedBox(height: 14),
          _Kmi30TopMoversCard(scheme: scheme),
          const SizedBox(height: 14),
          const _AboutStockSleeveCard(),
        ],
      ),
    );
  }
}

class _Kmi30LiveIndexCard extends StatelessWidget {
  const _Kmi30LiveIndexCard({
    required this.scheme,
    required this.indexTick,
    required this.klinesAsync,
  });

  final ColorScheme scheme;
  final AsyncValue<Kmi30IndexTick?> indexTick;
  final AsyncValue<List<Kmi30Bar>> klinesAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _GlassCard(
      accentColor: _psxGreen,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _psxGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            indexTick.when(
              loading: () => const LinearProgressIndicator(minHeight: 3),
              error: (_, __) => Text(
                "Index data unavailable",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              data: (tick) {
                if (tick == null) {
                  return Text(
                    "Index data unavailable",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  );
                }
                final pct = tick.changePercent;
                final changeColor = pct > 0
                    ? scheme.primary
                    : pct < 0
                        ? scheme.error
                        : scheme.onSurfaceVariant;
                final ptsStr =
                    "${tick.changeAbsolute >= 0 ? "+" : ""}${_indexFmt.format(tick.changeAbsolute)}";
                final pctStr =
                    "${pct >= 0 ? "+" : ""}${pct.toStringAsFixed(2)}%";

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.tr("mkt_stock_index_title"),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _indexFmt.format(tick.currentValue),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          ptsStr,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: changeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          pctStr,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: changeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _StatRow(
                      label: "Previous Close",
                      value: tick.previousClose != null
                          ? _indexFmt.format(tick.previousClose)
                          : "—",
                      scheme: scheme,
                    ),
                    _StatRow(
                      label: "Open",
                      value: tick.sessionOpen != null
                          ? _indexFmt.format(tick.sessionOpen)
                          : "—",
                      scheme: scheme,
                    ),
                    _StatRow(
                      label: "High",
                      value:
                          tick.high != null ? _indexFmt.format(tick.high) : "—",
                      scheme: scheme,
                    ),
                    _StatRow(
                      label: "Low",
                      value:
                          tick.low != null ? _indexFmt.format(tick.low) : "—",
                      scheme: scheme,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: klinesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Text(
                    context.tr("mkt_chart_unavailable"),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                data: (bars) {
                  if (bars.length < 2) {
                    return Center(
                      child: Text(
                        context.tr("mkt_insufficient_data"),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return Kmi30LineChart(
                    bars: bars,
                    timeframe: "1d",
                    color: _psxGreen,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockHoldingsCard extends StatelessWidget {
  const _StockHoldingsCard({
    required this.scheme,
    required this.slice,
    required this.stockAllocationPercent,
  });

  final ColorScheme scheme;
  final MarketSliceResult slice;
  final double stockAllocationPercent;

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

    return _GlassCard(
      accentColor: _psxGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                context.tr("mkt_stock_holdings_title"),
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
            value:
                "${stockAllocationPercent.toStringAsFixed(0)}% of portfolio",
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

class _Kmi30TopMoversCard extends ConsumerWidget {
  const _Kmi30TopMoversCard({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(kmi30CompanyAllocationsProvider);
    final withInv = list.where((e) => e.hasInvestment).toList();
    if (withInv.isEmpty) return const SizedBox.shrink();

    final gainers = [...withInv]
      ..sort((a, b) => b.todayProfitPkr.compareTo(a.todayProfitPkr));
    final losers = [...withInv]
      ..sort((a, b) => a.todayProfitPkr.compareTo(b.todayProfitPkr));
    final topG =
        gainers.where((e) => e.todayProfitPkr > 0).take(3).toList();
    final topL =
        losers.where((e) => e.todayProfitPkr < 0).take(3).toList();

    return _GlassCard(
      accentColor: _psxGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr("kmi30_top_movers_title"),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.tr("kmi30_top_gainers"),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (topG.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                "—",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            ...topG.map((e) => _MoverRow(alloc: e, isGain: true)),
          const SizedBox(height: 8),
          Text(
            context.tr("kmi30_top_losers"),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (topL.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "—",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            ...topL.map((e) => _MoverRow(alloc: e, isGain: false)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.push("/market/kmi30-companies"),
              child: Text(context.tr("kmi30_view_all_stocks")),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoverRow extends StatelessWidget {
  const _MoverRow({required this.alloc, required this.isGain});

  final Kmi30CompanyAllocation alloc;
  final bool isGain;

  @override
  Widget build(BuildContext context) {
    final pct = alloc.todayChangePct;
    final pctColor =
        isGain ? Colors.green.shade700 : Colors.red.shade700;
    final plSign = alloc.todayProfitPkr >= 0 ? "+" : "";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alloc.symbol,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  alloc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "$plSign${_money.format(alloc.todayProfitPkr)}",
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: pctColor,
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              "${pct >= 0 ? "+" : ""}${pct.toStringAsFixed(2)}%",
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: pctColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutStockSleeveCard extends StatelessWidget {
  const _AboutStockSleeveCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return _GlassCard(
      accentColor: _psxGreen,
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
              "Your stock allocation tracks the KMI-30 index — Pakistan's top "
              "30 Shariah-compliant companies listed on the Pakistan Stock "
              "Exchange (PSX). Returns reflect daily index movements during "
              "              market hours (Mon–Fri, 09:00–16:00 PKT).",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
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
