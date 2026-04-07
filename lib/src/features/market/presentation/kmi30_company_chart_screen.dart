import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_scaffold.dart";
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
    final tickAsync = ref.watch(selectedCompanyTickProvider(symbol));
    final klinesAsync = ref.watch(selectedCompanyKlinesProvider(symbol));
    final wsStatus = ref.watch(wsConnectionStatusProvider);
    final status = wsStatus.valueOrNull ?? PsxWsStatus.disconnected;
    final money = NumberFormat.decimalPatternDigits(decimalDigits: 2);

    return AppScaffold(
      title: "KMI30 • $symbol",
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(selectedCompanyKlinesProvider(symbol));
          if (status != PsxWsStatus.connected) {
            ref.invalidate(selectedCompanyRestFallbackTickProvider(symbol));
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                _WsIndicator(status: status),
                const SizedBox(width: 8),
                Text(
                  status == PsxWsStatus.connected
                      ? context.tr("market_ws_connected")
                      : status == PsxWsStatus.reconnecting
                          ? context.tr("market_ws_reconnecting")
                          : context.tr("market_ws_disconnected"),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.tr("market_ws_live_disclaimer"),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            tickAsync.when(
              data: (tick) {
                return _SummaryCard(
                  price: money.format(tick.price),
                  change: tick.change,
                  changePct: tick.changePercent,
                  high: money.format(tick.high),
                  low: money.format(tick.low),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) {
                if (status == PsxWsStatus.connected) {
                  return Text("${context.tr("error_prefix")} $e");
                }
                final fallback = ref.watch(selectedCompanyRestFallbackTickProvider(symbol));
                return fallback.when(
                  data: (t) => _SummaryCard(
                    price: money.format(t.price),
                    change: t.change,
                    changePct: t.changePercent,
                    high: money.format(t.high),
                    low: money.format(t.low),
                    fallback: true,
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e2, _) => _BothFailed(errorA: "$e", errorB: "$e2"),
                );
              },
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
    required this.price,
    required this.change,
    required this.changePct,
    required this.high,
    required this.low,
    this.fallback = false,
  });

  final String price;
  final double change;
  final double changePct;
  final String high;
  final String low;
  final bool fallback;

  @override
  Widget build(BuildContext context) {
    final pos = change >= 0;
    final c = pos ? Colors.green.shade700 : Colors.red.shade700;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("PKR $price", style: Theme.of(context).textTheme.headlineSmall),
          Text(
            "${change.toStringAsFixed(2)} (${(changePct * 100).toStringAsFixed(2)}%)",
            style: TextStyle(color: c, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text("${context.tr("market_high")}: $high")),
              Expanded(child: Text("${context.tr("market_low")}: $low")),
            ],
          ),
          if (fallback) ...[
            const SizedBox(height: 6),
            Text(context.tr("market_tick_fallback_used")),
          ],
        ],
      ),
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

class _BothFailed extends StatelessWidget {
  const _BothFailed({required this.errorA, required this.errorB});
  final String errorA;
  final String errorB;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr("market_live_fetch_failed")),
        const SizedBox(height: 4),
        Text("WS: $errorA"),
        Text("REST: $errorB"),
      ],
    );
  }
}
