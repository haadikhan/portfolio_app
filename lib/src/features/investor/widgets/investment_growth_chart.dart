import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../../core/theme/app_colors.dart";
import "../../../models/portfolio_model.dart";
import "../../../models/return_history_model.dart";

enum _Range { oneMonth, threeMonths, oneYear }

class InvestmentGrowthChart extends StatefulWidget {
  const InvestmentGrowthChart({
    super.key,
    required this.history,
    required this.portfolio,
  });

  /// All returnHistory entries, ordered by appliedAt ascending.
  final List<ReturnHistoryModel> history;

  /// Portfolio doc — used to prepend start point.
  final PortfolioModel? portfolio;

  @override
  State<InvestmentGrowthChart> createState() => _InvestmentGrowthChartState();
}

class _InvestmentGrowthChartState extends State<InvestmentGrowthChart> {
  _Range _range = _Range.oneYear;

  // ── Data preparation ────────────────────────────────────────────────────────

  List<_ChartPoint> _buildPoints() {
    final List<_ChartPoint> points = [];

    // Synthetic start point
    if (widget.portfolio != null) {
      points.add(_ChartPoint(
        date: widget.portfolio!.createdAt,
        value: widget.portfolio!.totalDeposited,
      ));
    }

    for (final r in widget.history) {
      points.add(_ChartPoint(date: r.appliedAt, value: r.newValue));
    }

    if (points.isEmpty) return points;

    // Apply time filter
    final now = DateTime.now();
    final cutoff = switch (_range) {
      _Range.oneMonth => now.subtract(const Duration(days: 30)),
      _Range.threeMonths => now.subtract(const Duration(days: 90)),
      _Range.oneYear => now.subtract(const Duration(days: 365)),
    };

    // Always keep the first (start) point
    final filtered =
        points.where((p) => p.date.isAfter(cutoff)).toList();
    if (filtered.isEmpty) {
      // If nothing in range, show last 2 points or all
      return points.length > 1 ? points.sublist(points.length - 2) : points;
    }

    // Prepend one point before the cutoff to give the chart a starting anchor
    final beforeCutoff = points.where((p) => !p.date.isAfter(cutoff)).toList();
    if (beforeCutoff.isNotEmpty) {
      filtered.insert(0, beforeCutoff.last);
    }

    return filtered;
  }

  // ── Formatting helpers ──────────────────────────────────────────────────────

  String _formatYAxis(double v) {
    if (v >= 1000000) return "${(v / 1000000).toStringAsFixed(1)}M";
    if (v >= 1000) return "${(v / 1000).toStringAsFixed(0)}K";
    return v.toStringAsFixed(0);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final points = _buildPoints();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Portfolio growth",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading,
                ),
              ),
              _RangeToggle(
                selected: _range,
                onChanged: (r) => setState(() => _range = r),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Chart ───────────────────────────────────────────────────
          SizedBox(
            height: 200,
            child: points.length < 2
                ? _PlaceholderChart(
                    value: widget.portfolio?.totalDeposited ?? 0)
                :         _LineChart(
                    points: points,
                    formatY: _formatYAxis,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Line chart widget ─────────────────────────────────────────────────────────

class _LineChart extends StatelessWidget {
  const _LineChart({
    required this.points,
    required this.formatY,
  });

  final List<_ChartPoint> points;
  final String Function(double) formatY;

  @override
  Widget build(BuildContext context) {
    final spots = points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

    final minY = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final yPad = ((maxY - minY) * 0.15).clamp(100.0, double.infinity);

    final dateFmt = DateFormat("MMM d");

    return LineChart(
      LineChartData(
        minY: (minY - yPad).clamp(0, double.infinity),
        maxY: maxY + yPad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY + 2 * yPad) / 4,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.border,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 54,
              getTitlesWidget: (v, meta) => Text(
                formatY(v),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.bodyMuted,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (points.length / 4).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (v, meta) {
                final idx = v.toInt();
                if (idx < 0 || idx >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    dateFmt.format(points[idx].date),
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.bodyMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) {
              final idx = s.x.toInt();
              final date = idx >= 0 && idx < points.length
                  ? DateFormat("MMM d, yyyy").format(points[idx].date)
                  : "";
              return LineTooltipItem(
                "$date\nPKR ${_compact(s.y)}",
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
            isCurved: spots.length >= 3,
            color: AppColors.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, i) => FlDotCirclePainter(
                radius: 3,
                color: AppColors.primary,
                strokeWidth: 1.5,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.25),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _compact(double v) {
    if (v >= 1000000) return "${(v / 1000000).toStringAsFixed(1)}M";
    if (v >= 1000) return "${(v / 1000).toStringAsFixed(0)}K";
    return v.toStringAsFixed(0);
  }
}

// ── Placeholder chart (< 2 data points) ──────────────────────────────────────

class _PlaceholderChart extends StatelessWidget {
  const _PlaceholderChart({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final spots = [FlSpot(0, value), FlSpot(1, value)];
    return Stack(
      children: [
        LineChart(
          LineChartData(
            minY: value * 0.9,
            maxY: value * 1.1 + 1,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: AppColors.border,
                barWidth: 2,
                dotData: const FlDotData(show: false),
                dashArray: [6, 4],
              ),
            ],
          ),
        ),
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart_rounded,
                  size: 28, color: AppColors.bodyMuted),
              SizedBox(height: 8),
              Text(
                "Chart will populate as returns are applied",
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.bodyMuted,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Range toggle ──────────────────────────────────────────────────────────────

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.selected, required this.onChanged});
  final _Range selected;
  final ValueChanged<_Range> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RangeBtn(
            label: "1M",
            active: selected == _Range.oneMonth,
            onTap: () => onChanged(_Range.oneMonth)),
        const SizedBox(width: 4),
        _RangeBtn(
            label: "3M",
            active: selected == _Range.threeMonths,
            onTap: () => onChanged(_Range.threeMonths)),
        const SizedBox(width: 4),
        _RangeBtn(
            label: "1Y",
            active: selected == _Range.oneYear,
            onTap: () => onChanged(_Range.oneYear)),
      ],
    );
  }
}

class _RangeBtn extends StatelessWidget {
  const _RangeBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.secondary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _ChartPoint {
  const _ChartPoint({required this.date, required this.value});
  final DateTime date;
  final double value;
}
