import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";

import "../../../../core/theme/app_colors.dart";

const _allocations = [
  _Allocation("Stock Market", 40, Color(0xFF0F7A2C)),
  _Allocation("Tech Products", 25, Color(0xFF2196F3)),
  _Allocation("Debt Market", 25, Color(0xFFFF9800)),
  _Allocation("Money Market", 5, Color(0xFF9C27B0)),
  _Allocation("Asset Market", 5, Color(0xFFE91E63)),
];

class _Allocation {
  const _Allocation(this.label, this.pct, this.color);
  final String label;
  final double pct;
  final Color color;
}

class AllocationPieChartWidget extends StatefulWidget {
  const AllocationPieChartWidget({super.key});

  @override
  State<AllocationPieChartWidget> createState() =>
      _AllocationPieChartWidgetState();
}

class _AllocationPieChartWidgetState extends State<AllocationPieChartWidget> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pie chart
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 48,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response?.touchedSection == null) {
                      _touched = -1;
                      return;
                    }
                    _touched =
                        response!.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sections: List.generate(_allocations.length, (i) {
                final a = _allocations[i];
                final isTouched = i == _touched;
                return PieChartSectionData(
                  value: a.pct,
                  color: a.color,
                  radius: isTouched ? 72 : 60,
                  title: "${a.pct.toInt()}%",
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Percentage bars
        ..._allocations.map((a) => _AllocationBar(allocation: a)),

        const SizedBox(height: 14),

        // Disclaimer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: AppColors.bodyMuted),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Allocation is indicative and for representation purposes only",
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.bodyMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AllocationBar extends StatelessWidget {
  const _AllocationBar({required this.allocation});
  final _Allocation allocation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: allocation.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    allocation.label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.body,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                "${allocation.pct.toInt()}%",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: allocation.pct / 100,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(allocation.color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
