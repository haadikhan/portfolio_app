import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../data/models/gold_price_quote.dart";
import "../data/models/kmi30_bar.dart";
import "providers/kmi30_companies_providers.dart";
import "widgets/candle_chart_painter.dart";
import "widgets/kmi30_line_chart.dart";

/// Gold detail: matches [Kmi30CompanyChartScreen] layout (uses gold-only providers).
class GoldPriceChartScreen extends ConsumerWidget {
  const GoldPriceChartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tf = ref.watch(goldChartTimeframeProvider);
    final chartType = ref.watch(goldChartTypeProvider);
    final live = ref.watch(goldPriceStreamProvider);
    final initial = ref.watch(goldPriceInitialProvider);
    final fallback = ref.watch(goldPriceLastKnownProvider);
    final quote = live.valueOrNull ?? initial.valueOrNull ?? fallback;
    final klinesAsync = ref.watch(goldDetailKlinesProvider);

    final money = NumberFormat.decimalPatternDigits(decimalDigits: 2);

    return AppScaffold(
      title: context.tr("gold_detail_title"),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(goldPriceRefreshCounterProvider.notifier).refresh();
          ref.invalidate(goldPriceInitialProvider);
          ref.invalidate(goldDetailKlinesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1D9E75),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr("gold_spot_feed_status"),
                    maxLines: 2,
                    softWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.tr("gold_spot_disclaimer"),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final chartBars =
                    klinesAsync.valueOrNull ?? const <Kmi30Bar>[];
                final dailyBars =
                    tf.toLowerCase() == "1d" ? chartBars : const <Kmi30Bar>[];
                final hasAny = quote != null || chartBars.isNotEmpty;

                if (quote == null && klinesAsync.isLoading && !hasAny) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (quote == null && klinesAsync.hasError && chartBars.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "${context.tr("error_prefix")} ${klinesAsync.error}",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  );
                }
                if (klinesAsync.hasError && chartBars.isEmpty && quote == null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "${context.tr("error_prefix")} ${klinesAsync.error}",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  );
                }
                return _GoldSummaryCard(
                  quote: quote,
                  timeframe: tf,
                  chartBars: chartBars,
                  dailyBars: dailyBars,
                  money: money,
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
                          onSelected: (_) {
                            ref.read(goldChartTimeframeProvider.notifier).state =
                                v;
                            ref.invalidate(goldDetailKlinesProvider);
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: "line",
                  label: Text(context.tr("market_line")),
                ),
                ButtonSegment(
                  value: "candle",
                  label: Text(context.tr("market_candle")),
                ),
              ],
              selected: {chartType},
              onSelectionChanged: (s) =>
                  ref.read(goldChartTypeProvider.notifier).state = s.first,
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

class _GoldSummaryCard extends StatelessWidget {
  const _GoldSummaryCard({
    required this.quote,
    required this.timeframe,
    required this.chartBars,
    required this.dailyBars,
    required this.money,
  });

  final GoldPriceQuote? quote;
  final String timeframe;
  final List<Kmi30Bar> chartBars;
  final List<Kmi30Bar> dailyBars;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lastBar = chartBars.isNotEmpty ? chartBars.last : null;
    final prevChartBar =
        chartBars.length > 1 ? chartBars[chartBars.length - 2] : null;

    final double lastPrice;
    if (quote != null && quote!.xauPkr > 0) {
      lastPrice = quote!.xauPkr;
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
      openVal = latestDaily.open;
      highVal = latestDaily.high;
      lowVal = latestDaily.low;
      closeVal = lastPrice;
      if (lastPrice > highVal) highVal = lastPrice;
      if (lastPrice < lowVal) lowVal = lastPrice;
      if (prevClose != null && prevClose > 0) {
        changePct = (lastPrice - prevClose) / prevClose * 100;
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
        changePct =
            (lastPrice - prevChartBar.close) / prevChartBar.close * 100;
      } else if (openVal > 0) {
        changePct = (closeVal - openVal) / openVal * 100;
      } else {
        changePct = 0;
      }
    } else if (quote != null) {
      periodLabel = context.tr("gold_spot_only_stats");
      openVal = quote!.xauPkr;
      highVal = quote!.xauPkr;
      lowVal = quote!.xauPkr;
      closeVal = quote!.xauPkr;
      changePct = 0;
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
          if (quote != null) ...[
            const SizedBox(height: 8),
            Text(
              "${context.tr("gold_price_xau_usd")}: USD ${NumberFormat("#,##0.00", "en_US").format(quote!.xauUsd)} · "
              "${context.tr("gold_last_updated")}: ${DateFormat.yMMMd().add_Hm().format(quote!.timestamp.toLocal())}",
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
