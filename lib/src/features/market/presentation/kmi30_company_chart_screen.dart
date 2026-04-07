import "dart:math";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../data/models/kmi30_bar.dart";
import "../data/models/kmi30_tick.dart";
import "../data/websocket/psx_websocket_service.dart";
import "providers/kmi30_companies_providers.dart";
import "widgets/candle_chart_painter.dart";
import "widgets/kmi30_line_chart.dart";

class Kmi30CompanyChartScreen extends ConsumerWidget {
  const Kmi30CompanyChartScreen({super.key, required this.symbol});

  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tf = ref.watch(selectedTimeframeProvider);
    final chartType = ref.watch(selectedChartTypeProvider);
    final restAsync = ref.watch(kmi30RestTickProvider(symbol));
    final liveAsync = ref.watch(selectedCompanyLiveTickStreamProvider(symbol));
    final dailyAsync = ref.watch(companyDailyOhlcBarsProvider(symbol));
    final klinesAsync = ref.watch(selectedCompanyKlinesProvider(symbol));
    final wsStatus = ref.watch(wsConnectionStatusProvider);
    final status = wsStatus.valueOrNull ?? PsxWsStatus.disconnected;
    final money = NumberFormat.decimalPatternDigits(decimalDigits: 2);

    final liveTick = liveAsync.valueOrNull;
    final restTick = restAsync.valueOrNull;
    final effectiveTick = liveTick ?? restTick;

    return AppScaffold(
      title: "KMI30 • $symbol",
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(kmi30RestTickProvider(symbol));
          ref.invalidate(selectedCompanyKlinesProvider(symbol));
          ref.invalidate(companyDailyOhlcBarsProvider(symbol));
          if (status != PsxWsStatus.connected) {
            ref.invalidate(selectedCompanyRestFallbackTickProvider(symbol));
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _WsIndicator(status: status),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status == PsxWsStatus.connected
                        ? context.tr("market_ws_connected")
                        : status == PsxWsStatus.reconnecting
                            ? context.tr("market_ws_reconnecting")
                            : context.tr("market_ws_disconnected"),
                    maxLines: 2,
                    softWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.tr("market_ws_live_disclaimer"),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final chartBars = klinesAsync.valueOrNull ?? const [];
                final dailyBars = dailyAsync.valueOrNull ?? const [];
                final hasAny =
                    effectiveTick != null || chartBars.isNotEmpty || dailyBars.isNotEmpty;

                if (effectiveTick == null && restAsync.isLoading && !hasAny) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (effectiveTick == null && restAsync.hasError && !hasAny) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "${context.tr("error_prefix")} ${restAsync.error}",
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  );
                }
                if (klinesAsync.hasError &&
                    chartBars.isEmpty &&
                    effectiveTick == null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "${context.tr("error_prefix")} ${klinesAsync.error}",
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  );
                }
                return _SummaryCard(
                  tick: effectiveTick,
                  timeframe: tf,
                  chartBars: chartBars,
                  dailyBars: dailyBars,
                  money: money,
                  useRestFallback: liveTick == null && restTick != null,
                );
              },
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.hardEdge,
              child: Row(
                children: ["1m", "5m", "15m", "1h", "4h", "1d"]
                    .map(
                      (v) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(v),
                          selected: tf == v,
                          onSelected: (_) =>
                              ref.read(selectedTimeframeProvider.notifier).state = v,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: "line", label: Text(context.tr("market_line"))),
                ButtonSegment(value: "candle", label: Text(context.tr("market_candle"))),
              ],
              selected: {chartType},
              onSelectionChanged: (s) =>
                  ref.read(selectedChartTypeProvider.notifier).state = s.first,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 340,
              child: klinesAsync.when(
                data: (bars) {
                  if (bars.isEmpty) {
                    return Center(child: Text(context.tr("market_no_data")));
                  }
                  return chartType == "candle"
                      ? CandleChartView(bars: bars)
                      : Kmi30LineChart(bars: bars, timeframe: tf);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text("${context.tr("error_prefix")} $e"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.tick,
    required this.timeframe,
    required this.chartBars,
    required this.dailyBars,
    required this.money,
    this.useRestFallback = false,
  });

  final Kmi30Tick? tick;
  final String timeframe;
  final List<Kmi30Bar> chartBars;
  final List<Kmi30Bar> dailyBars;
  final NumberFormat money;
  final bool useRestFallback;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lastBar = chartBars.isNotEmpty ? chartBars.last : null;
    final prevChartBar =
        chartBars.length > 1 ? chartBars[chartBars.length - 2] : null;

    final double lastPrice;
    if (tick != null && tick!.price > 0) {
      lastPrice = tick!.price;
    } else if (lastBar != null) {
      lastPrice = lastBar.close;
    } else {
      lastPrice = 0;
    }

    final isDailyTf = timeframe.toLowerCase() == "1d";
    final latestDaily = dailyBars.isNotEmpty ? dailyBars.last : null;
    final prevDaily = dailyBars.length > 1 ? dailyBars[dailyBars.length - 2] : null;

    double changePct;
    double openVal;
    double highVal;
    double lowVal;
    double closeVal;
    String periodLabel;

    if (isDailyTf && latestDaily != null) {
      periodLabel = context.tr("market_daily_stats");
      final prevClose = prevDaily?.close;
      openVal = tick?.open ?? latestDaily.open;
      highVal = max(tick?.high ?? 0, latestDaily.high);
      lowVal = min(tick?.low ?? double.infinity, latestDaily.low);
      if (tick != null) {
        if (lastPrice > highVal) highVal = lastPrice;
        if (lastPrice < lowVal) lowVal = lastPrice;
      }
      closeVal = lastPrice;
      if (prevClose != null && prevClose > 0) {
        changePct = (lastPrice - prevClose) / prevClose * 100;
      } else if (tick != null) {
        changePct = displayKmi30Percent(tick!.changePercent);
      } else {
        changePct = 0;
      }
    } else if (lastBar != null) {
      periodLabel = context.trParams("market_period_stats", {"tf": timeframe});
      openVal = lastBar.open;
      highVal = lastBar.high;
      lowVal = lastBar.low;
      closeVal = lastPrice;
      if (lastPrice > highVal) highVal = lastPrice;
      if (lastPrice < lowVal) lowVal = lastPrice;
      if (prevChartBar != null && prevChartBar.close > 0) {
        changePct = (lastPrice - prevChartBar.close) / prevChartBar.close * 100;
      } else if (openVal > 0) {
        changePct = (closeVal - openVal) / openVal * 100;
      } else {
        changePct = tick != null ? displayKmi30Percent(tick!.changePercent) : 0;
      }
    } else if (tick != null) {
      periodLabel = context.tr("market_live_quote");
      openVal = tick!.open ?? tick!.price - tick!.change;
      highVal = tick!.high;
      lowVal = tick!.low;
      closeVal = lastPrice;
      changePct = displayKmi30Percent(tick!.changePercent);
    } else {
      return const SizedBox.shrink();
    }

    final double moveAbs;
    if (isDailyTf && prevDaily != null && prevDaily.close > 0) {
      moveAbs = lastPrice - prevDaily.close;
    } else if (!isDailyTf && prevChartBar != null && prevChartBar.close > 0) {
      moveAbs = lastPrice - prevChartBar.close;
    } else {
      moveAbs = lastPrice - openVal;
    }
    final pos = changePct >= 0;
    final c = pos ? Colors.green.shade700 : Colors.red.shade700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            periodLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr("market_last"),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          Text(
            "PKR ${money.format(lastPrice)}",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            "${context.tr("market_change_pct")} ${changePct >= 0 ? "+" : ""}${changePct.toStringAsFixed(2)}% "
            "(${moveAbs >= 0 ? "+" : ""}${money.format(moveAbs)})",
            style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricLine(
                  label: context.tr("market_open"),
                  value: money.format(openVal),
                ),
              ),
              Expanded(
                child: _MetricLine(
                  label: context.tr("market_close"),
                  value: money.format(closeVal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _MetricLine(
                  label: context.tr("market_high"),
                  value: money.format(highVal),
                ),
              ),
              Expanded(
                child: _MetricLine(
                  label: context.tr("market_low"),
                  value: money.format(lowVal),
                ),
              ),
            ],
          ),
          if (isDailyTf && prevDaily != null) ...[
            const SizedBox(height: 6),
            Text(
              "${context.tr("market_prev_close")}: ${money.format(prevDaily.close)}",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (!isDailyTf && prevChartBar != null) ...[
            const SizedBox(height: 6),
            Text(
              "${context.tr("market_prev_bar_close")}: ${money.format(prevChartBar.close)}",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (useRestFallback) ...[
            const SizedBox(height: 8),
            Text(
              context.tr("market_tick_fallback_used"),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _WsIndicator extends StatelessWidget {
  const _WsIndicator({required this.status});
  final PsxWsStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status == PsxWsStatus.connected ? Colors.green : Colors.red;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

