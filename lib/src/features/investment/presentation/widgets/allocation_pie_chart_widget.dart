import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";

import "../../../../core/i18n/app_translations.dart";

List<_Allocation> _allocationsFor(BuildContext context) => [
      _Allocation(context.tr("alloc_stock_market"), 40, const Color(0xFF0F7A2C)),
      _Allocation(context.tr("alloc_tech"), 25, const Color(0xFF2196F3)),
      _Allocation(context.tr("alloc_debt"), 25, const Color(0xFFFF9800)),
      _Allocation(context.tr("alloc_money"), 5, const Color(0xFF9C27B0)),
      _Allocation(context.tr("alloc_asset"), 5, const Color(0xFFE91E63)),
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
    final allocations = _allocationsFor(context);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              sections: List.generate(allocations.length, (i) {
                final a = allocations[i];
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
        ...allocations.map((a) => _AllocationBar(allocation: a)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.tr("allocation_disclaimer"),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
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
    final scheme = Theme.of(context).colorScheme;
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
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                "${allocation.pct.toInt()}%",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: allocation.pct / 100,
              backgroundColor: scheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(allocation.color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
