import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../../../core/theme/app_colors.dart";
import "../../data/founder_performance_data.dart";

final _monthFmt = DateFormat("MMM yy");

class FounderPerformanceChart extends StatelessWidget {
  const FounderPerformanceChart({super.key, required this.points});

  final List<FounderPerformancePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final minY = points.map((p) => p.valuePkr).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.valuePkr).reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.08;
    final chartMin = minY - pad;
    final chartMax = maxY + pad;
    final maxX = (points.length - 1).toDouble();

    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].valuePkr),
    ];

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: chartMin,
          maxY: chartMax,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (chartMax - chartMin) / 4,
            getDrawingHorizontalLine: (v) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, _) => Text(
                  _formatY(v),
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
                reservedSize: 26,
                interval: (maxX / 4).clamp(1, maxX),
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _monthFmt.format(points[i].month),
                      style: TextStyle(
                        fontSize: 9,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touched) => touched.map((s) {
                final idx = s.x.toInt();
                final label = idx >= 0 && idx < points.length
                    ? _monthFmt.format(points[idx].month)
                    : "";
                return LineTooltipItem(
                  "$label\nPKR ${s.y.toStringAsFixed(0)}",
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatY(double v) {
    if (v >= 1e6) return "${(v / 1e6).toStringAsFixed(1)}M";
    if (v >= 1e3) return "${(v / 1e3).toStringAsFixed(0)}K";
    return v.toStringAsFixed(0);
  }
}
