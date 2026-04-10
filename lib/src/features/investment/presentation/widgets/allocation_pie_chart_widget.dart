import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../../../core/i18n/app_translations.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);

List<_Allocation> _allocationsFor(BuildContext context, double totalAmountPkr) => [
      _Allocation(
        context.tr("alloc_stock_market"),
        40,
        const Color(0xFF0F7A2C),
        _deriveAmount(totalAmountPkr, 40),
      ),
      _Allocation(
        context.tr("alloc_tech"),
        25,
        const Color(0xFF2196F3),
        _deriveAmount(totalAmountPkr, 25),
      ),
      _Allocation(
        context.tr("alloc_debt"),
        25,
        const Color(0xFFFF9800),
        _deriveAmount(totalAmountPkr, 25),
      ),
      _Allocation(
        context.tr("alloc_money"),
        5,
        const Color(0xFF9C27B0),
        _deriveAmount(totalAmountPkr, 5),
      ),
      _Allocation(
        context.tr("alloc_asset"),
        5,
        const Color(0xFFE91E63),
        _deriveAmount(totalAmountPkr, 5),
      ),
    ];

double _deriveAmount(double total, double percentage) {
  if (!total.isFinite || total <= 0) return 0;
  return total * (percentage / 100);
}

String _formatMoney(double value) {
  if (!value.isFinite || value <= 0) return _money.format(0);
  return _money.format(value);
}

class _Allocation {
  const _Allocation(this.label, this.pct, this.color, this.amountPkr);
  final String label;
  final double pct;
  final Color color;
  final double amountPkr;
}

class AllocationPieChartWidget extends StatefulWidget {
  const AllocationPieChartWidget({
    super.key,
    this.totalAmountPkr = 0,
  });

  final double totalAmountPkr;

  @override
  State<AllocationPieChartWidget> createState() =>
      _AllocationPieChartWidgetState();
}

class _AllocationPieChartWidgetState extends State<AllocationPieChartWidget> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final allocations = _allocationsFor(context, widget.totalAmountPkr);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primary.withValues(alpha: 0.10),
                scheme.tertiary.withValues(alpha: 0.10),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                size: 16,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatMoney(widget.totalAmountPkr),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Text(
                context.tr("current_portfolio_value"),
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
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
                        _touched = response!.touchedSection!.touchedSectionIndex;
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
              IgnorePointer(
                child: Container(
                  width: 92,
                  height: 92,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "TOTAL",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatMoney(widget.totalAmountPkr),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
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
                    Flexible(
                      child: Text(
                        allocation.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatMoney(allocation.amountPkr),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    "${allocation.pct.toInt()}%",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: allocation.color.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: allocation.pct / 100,
                backgroundColor: scheme.outlineVariant.withValues(alpha: 0.45),
                valueColor: AlwaysStoppedAnimation<Color>(allocation.color),
                minHeight: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
