import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../data/models/kmi30_bar.dart";

class Kmi30LineChart extends StatelessWidget {
  const Kmi30LineChart({
    super.key,
    required this.bars,
    required this.timeframe,
  });

  final List<Kmi30Bar> bars;
  final String timeframe;

  @override
  Widget build(BuildContext context) {
    if (bars.length < 2) {
      return const Center(child: Text("Not enough chart data"));
    }
    final scheme = Theme.of(context).colorScheme;
    final spots = bars
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.close))
        .toList();
    final minY = bars.map((e) => e.close).reduce((a, b) => a < b ? a : b);
    final maxY = bars.map((e) => e.close).reduce((a, b) => a > b ? a : b);
    final yPad = ((maxY - minY) * 0.1).clamp(0.5, double.infinity);

    return LineChart(
      LineChartData(
        minY: (minY - yPad).clamp(0, double.infinity),
        maxY: maxY + yPad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 10,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (bars.length / 4).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= bars.length) return const SizedBox.shrink();
                final fmt = _xFormatter(timeframe);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    fmt.format(bars[i].timestamp),
                    style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (items) => items.map((item) {
              final idx = item.x.toInt();
              final b = idx >= 0 && idx < bars.length ? bars[idx] : null;
              if (b == null) return null;
              return LineTooltipItem(
                "${DateFormat("dd MMM yyyy HH:mm").format(b.timestamp)}\n"
                "Close: ${b.close.toStringAsFixed(2)}",
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              );
            }).whereType<LineTooltipItem>().toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: spots.length >= 3,
            color: const Color(0xFF1D9E75),
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: const LinearGradient(
                colors: [Color(0x441D9E75), Color(0x001D9E75)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  DateFormat _xFormatter(String timeframe) {
    switch (timeframe) {
      case "1m":
      case "5m":
      case "15m":
      case "1h":
      case "4h":
        return DateFormat("HH:mm");
      case "1d":
      default:
        return DateFormat("dd MMM");
    }
  }
}
