import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "package:portfolio_app/src/core/i18n/app_translations.dart";
import "package:portfolio_app/src/core/widgets/app_scaffold.dart";
import "package:portfolio_app/src/features/investment/presentation/market_detail/sleeve_report_download.dart";
import "package:portfolio_app/src/features/investment/data/allocation_money_market.dart";
import "package:portfolio_app/src/features/investment/domain/five_market_models.dart";
import "package:portfolio_app/src/features/investment/domain/market_sleeve_balance.dart";
import "package:portfolio_app/src/features/investment/providers/five_market_providers.dart";
import "package:portfolio_app/src/features/investment/providers/market_sleeve_balance_provider.dart";
import "package:portfolio_app/src/features/investment/presentation/five_market_daily_providers.dart";
import "package:portfolio_app/src/features/market/data/models/kmi30_bar.dart";
import "package:portfolio_app/src/features/market/data/models/kmi30_index_tick.dart";
import "package:portfolio_app/src/features/market/presentation/widgets/kmi30_line_chart.dart";
import "package:portfolio_app/src/features/market/providers/kmi30_index_provider.dart";
import "package:portfolio_app/src/providers/wallet_providers.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);
final _indexFmt = NumberFormat.decimalPatternDigits(decimalDigits: 2);
final _indexVolFmt = NumberFormat.decimalPattern();

/// Investor dashboard: estimated daily P&amp;L across five market sleeves (Phase 4).
class FiveMarketDailyScreen extends ConsumerWidget {
  const FiveMarketDailyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final configAsync = ref.watch(fiveMarketConfigProvider);
    final walletAsync = ref.watch(userWalletStreamProvider);
    final tradingDay = ref.watch(todayTradingDayProvider);
    final dailyResult = ref.watch(fiveMarketDailyResultProvider);
    final indexTick = ref.watch(kmi30IndexTickProvider);
    final eodAsync = ref.watch(latestEodSnapshotProvider);
    final klinesAsync = ref.watch(kmi30IndexDailyKlinesProvider);
    final sleeveSnap = ref.watch(marketSleeveBalancesProvider);

    return AppScaffold(
      title: context.tr("five_market_daily_title"),
      actions: [
        IconButton(
          icon: const Icon(Icons.download_outlined),
          tooltip: context.tr("five_market_download_report"),
          onPressed: () => openCombinedSleeveReportDownload(
            context: context,
            ref: ref,
          ),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(kmi30IndexDailyKlinesProvider);
          ref.invalidate(fiveMarketConfigProvider);
          ref.invalidate(userWalletStreamProvider);
          ref.invalidate(fiveMarketDailyHistoryProvider);
          ref.invalidate(kmi30IndexTickProvider);
          await Future<void>.delayed(const Duration(milliseconds: 500));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (configAsync.isLoading || walletAsync.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (configAsync.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "${context.tr("error_prefix")} ${configAsync.error}",
                      style: TextStyle(color: scheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else if (walletAsync.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "${context.tr("error_prefix")} ${walletAsync.error}",
                      style: TextStyle(color: scheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              ..._bodySlivers(
                context,
                ref,
                scheme,
                tradingDay,
                dailyResult,
                indexTick,
                eodAsync,
                klinesAsync,
                walletAsync.valueOrNull,
                sleeveSnap,
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _bodySlivers(
    BuildContext context,
    WidgetRef ref,
    ColorScheme scheme,
    TradingDayResult tradingDay,
    FiveMarketDailyResult? dailyResult,
    AsyncValue<Kmi30IndexTick?> indexTick,
    AsyncValue<Map<String, dynamic>?> eodAsync,
    AsyncValue<List<Kmi30Bar>> klinesAsync,
    Map<String, dynamic>? wallet,
    SleeveBalanceSnapshot? sleeveSnap,
  ) {
    final base = allocationTotalFromWallet(wallet);
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _ClosedDayBanner(
            tradingDay: tradingDay,
            scheme: scheme,
          ),
        ),
      ),
      if (base <= 0)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: scheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.tr("five_market_zero_base_message"),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: _EodFootnote(async: eodAsync, scheme: scheme),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _Kmi30HeroCard(
            indexTick: indexTick,
            klinesAsync: klinesAsync,
            scheme: scheme,
            onChartRetry: () => ref.invalidate(kmi30IndexDailyKlinesProvider),
          ),
        ),
      ),
    ];

    if (dailyResult == null) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text(context.tr("five_market_loading_breakdown"))),
        ),
      );
      return slivers;
    }

    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.tr("five_market_breakdown_title"),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
          ),
        ),
      ),
    );
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));

    final todayCredited = sleeveSnap?.todayFiveMarketCredited ?? false;
    void addRow(
      String labelKey,
      MarketSliceResult slice,
      String route,
      MarketSleeve sleeve,
    ) {
      final entry = sleeveSnap?[sleeve];
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _MarketSliceTile(
              label: context.tr(labelKey),
              marketSleeve: sleeve,
              slice: slice,
              scheme: scheme,
              sleeveEntry: entry,
              todayCreditedToWallet: todayCredited,
              onTap: () => context.push(route),
            ),
          ),
        ),
      );
    }

    addRow(
      "five_market_row_stock",
      dailyResult.stock,
      "/five-market/stock",
      MarketSleeve.stock,
    );
    addRow(
      "five_market_row_tech",
      dailyResult.tech,
      "/five-market/tech",
      MarketSleeve.tech,
    );
    addRow(
      "five_market_row_debt",
      dailyResult.debt,
      "/five-market/debt",
      MarketSleeve.debt,
    );
    addRow(
      "five_market_row_money",
      dailyResult.money,
      "/five-market/money",
      MarketSleeve.money,
    );
    addRow(
      "five_market_row_gold",
      dailyResult.gold,
      "/five-market/gold",
      MarketSleeve.gold,
    );

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 12)));
    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: _TotalProfitCard(
            total: dailyResult.totalProfitPkr,
            portfolioTotalPkr: sleeveSnap?.totalDisplayPkr,
            scheme: scheme,
          ),
        ),
      ),
    );

    return slivers;
  }
}

class _ClosedDayBanner extends StatelessWidget {
  const _ClosedDayBanner({
    required this.tradingDay,
    required this.scheme,
  });

  final TradingDayResult tradingDay;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    if (tradingDay.isTradingDay) {
      return const SizedBox.shrink();
    }
    final subKey = switch (tradingDay.source) {
      TradingDaySource.forceOpen => "five_market_closed_sub_force_open",
      TradingDaySource.forceClosed => "five_market_closed_sub_force_closed",
      TradingDaySource.weekend => "five_market_closed_sub_weekend",
      TradingDaySource.holiday => "five_market_closed_sub_holiday",
      TradingDaySource.calendar => "five_market_closed_sub_calendar",
    };
    return Card(
      color: scheme.errorContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_busy_rounded, color: scheme.error, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr("five_market_closed_banner_title"),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onErrorContainer,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(subKey),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EodFootnote extends StatelessWidget {
  const _EodFootnote({
    required this.async,
    required this.scheme,
  });

  final AsyncValue<Map<String, dynamic>?> async;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return async.when(
      data: (doc) {
        if (doc == null) return const SizedBox.shrink();
        final date = doc["date"]?.toString();
        if (date == null || date.isEmpty) return const SizedBox.shrink();
        return Text(
          context.trParams("five_market_eod_footnote", {"date": date}),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
              ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _Kmi30HeroCard extends StatelessWidget {
  const _Kmi30HeroCard({
    required this.indexTick,
    required this.klinesAsync,
    required this.scheme,
    required this.onChartRetry,
  });

  final AsyncValue<Kmi30IndexTick?> indexTick;
  final AsyncValue<List<Kmi30Bar>> klinesAsync;
  final ColorScheme scheme;
  final VoidCallback onChartRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: scheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr("five_market_kmi30_section_title"),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            indexTick.when(
              data: (tick) {
                if (tick == null) {
                  return Text(
                    context.tr("five_market_index_unavailable"),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  );
                }
                final pct = tick.changePercent;
                final pctColor = pct > 0
                    ? scheme.primary
                    : pct < 0
                        ? scheme.error
                        : scheme.onSurfaceVariant;
                final ptsStr =
                    "${tick.changeAbsolute >= 0 ? "+" : ""}${_indexFmt.format(tick.changeAbsolute)}";
                final dash = context.tr("five_market_kmi30_value_dash");
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.tr("five_market_kmi30_last_label"),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _indexFmt.format(tick.currentValue),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          ptsStr,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: pctColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          "${pct >= 0 ? "+" : ""}${pct.toStringAsFixed(2)}%",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: pctColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    if (!tick.dayChangeUsesPriorClose) ...[
                      const SizedBox(height: 8),
                      Text(
                        context.tr("five_market_kmi30_change_fallback_note"),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _Kmi30StatRow(
                      label: context.tr("five_market_kmi30_previous_close"),
                      value: tick.previousClose != null
                          ? _indexFmt.format(tick.previousClose!)
                          : dash,
                      scheme: scheme,
                    ),
                    if (tick.sessionOpen != null)
                      _Kmi30StatRow(
                        label: context.tr("five_market_kmi30_open"),
                        value: _indexFmt.format(tick.sessionOpen!),
                        scheme: scheme,
                      ),
                    if (tick.high != null)
                      _Kmi30StatRow(
                        label: context.tr("five_market_kmi30_high"),
                        value: _indexFmt.format(tick.high!),
                        scheme: scheme,
                      ),
                    if (tick.low != null)
                      _Kmi30StatRow(
                        label: context.tr("five_market_kmi30_low"),
                        value: _indexFmt.format(tick.low!),
                        scheme: scheme,
                      ),
                    if (tick.volume != null)
                      _Kmi30StatRow(
                        label: context.tr("five_market_kmi30_volume"),
                        value: _indexVolFmt.format(tick.volume!),
                        scheme: scheme,
                      ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(minHeight: 3),
              error: (_, __) => Text(
                context.tr("five_market_index_unavailable"),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: klinesAsync.when(
                data: (bars) {
                  if (bars.length < 2) {
                    return Center(
                      child: Text(
                        context.tr("market_no_data"),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    );
                  }
                  return Kmi30LineChart(bars: bars, timeframe: "1d");
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${context.tr("error_prefix")} $e",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error, fontSize: 13),
                    ),
                    TextButton(
                      onPressed: onChartRetry,
                      child: Text(context.tr("five_market_chart_retry")),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Kmi30StatRow extends StatelessWidget {
  const _Kmi30StatRow({
    required this.label,
    required this.value,
    required this.scheme,
  });

  final String label;
  final String value;
  final ColorScheme scheme;

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
                    color: scheme.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketSliceTile extends StatelessWidget {
  const _MarketSliceTile({
    required this.label,
    required this.marketSleeve,
    required this.slice,
    required this.scheme,
    this.sleeveEntry,
    this.todayCreditedToWallet = false,
    this.onTap,
  });

  final String label;
  final MarketSleeve marketSleeve;
  final MarketSliceResult slice;
  final ColorScheme scheme;
  /// Full sleeve row from [marketSleeveBalancesProvider] when loaded.
  final SleeveBalanceEntry? sleeveEntry;
  final bool todayCreditedToWallet;
  final VoidCallback? onTap;

  String _sliceSubtitle(BuildContext context) {
    final annual = slice.annualPercent;
    if (annual != null) {
      return "${annual.toStringAsFixed(1)}% ${context.tr("five_market_per_annum")}";
    }
    final pct = slice.changePercent;
    return pct >= 0
        ? "+${pct.toStringAsFixed(2)}%"
        : "${pct.toStringAsFixed(2)}%";
  }

  Color _sliceSubtitleColor() {
    if (slice.annualPercent != null) {
      return scheme.onSurfaceVariant;
    }
    final pct = slice.changePercent;
    if (pct > 0) return scheme.primary;
    if (pct < 0) return scheme.error;
    return scheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final displayPkr = sleeveEntry?.displayPkr;
    final profit = slice.profitPkr;
    final profitColor = profit > 0
        ? scheme.primary
        : profit < 0
            ? scheme.error
            : scheme.onSurfaceVariant;
    final statusKey = switch (slice.status) {
      MarketSliceStatus.live => "five_market_status_live",
      MarketSliceStatus.realized => "five_market_status_realized",
      MarketSliceStatus.closed => "five_market_status_closed",
      MarketSliceStatus.nonTradingDay => "five_market_status_non_trading",
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: scheme.outline.withValues(alpha: 0.12),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _sliceSubtitle(context),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _sliceSubtitleColor(),
                          ),
                    ),
                    const SizedBox(height: 4),
                    if (marketSleeve == MarketSleeve.money &&
                        sleeveEntry != null) ...[
                      Text(
                        context.trParams(
                          "five_market_money_withdrawable_line",
                          {"amount": _money.format(sleeveEntry!.basePkr)},
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.trParams(
                          "five_market_money_return_notional_line",
                          {"amount": _money.format(slice.allocatedPkr)},
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontSize: 11,
                              height: 1.25,
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ] else ...[
                      Text(
                        context.trParams(
                          "five_market_allocated_label",
                          {"amount": _money.format(slice.allocatedPkr)},
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    if (displayPkr != null && displayPkr.isFinite) ...[
                      const SizedBox(height: 2),
                      Text(
                        context.trParams(
                          "five_market_sleeve_value_label",
                          {"amount": _money.format(displayPkr)},
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                    if (todayCreditedToWallet) ...[
                      const SizedBox(height: 2),
                      Text(
                        context.tr("five_market_credited_to_wallet_status"),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ] else if (slice.status == MarketSliceStatus.realized) ...[
                      const SizedBox(height: 2),
                      Text(
                        context.tr("five_market_pending_overnight_credit"),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${profit >= 0 ? "+" : ""}${_money.format(profit)}",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: profitColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Container(
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
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalProfitCard extends StatelessWidget {
  const _TotalProfitCard({
    required this.total,
    this.portfolioTotalPkr,
    required this.scheme,
  });

  final double total;
  final double? portfolioTotalPkr;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final c = total > 0
        ? scheme.primary
        : total < 0
            ? scheme.error
            : scheme.onSurfaceVariant;
    final pt = portfolioTotalPkr;
    return Card(
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: 0.22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr("five_market_total_label"),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(
                  "${total >= 0 ? "+" : ""}${_money.format(total)}",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: c,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            if (pt != null && pt.isFinite && pt > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr("five_market_portfolio_total_incl_pending"),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                    ),
                  ),
                  Text(
                    _money.format(pt),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
