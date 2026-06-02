import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../../../core/i18n/app_translations.dart";
import "../../data/allocation_money_market.dart";
import "../../domain/five_market_models.dart";
import "../../domain/market_sleeve_balance.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);

const _allocationColors = <Color>[
  Color(0xFF0F7A2C),
  Color(0xFF2196F3),
  Color(0xFFFF9800),
  Color(0xFF9C27B0),
  Color(0xFFE91E63),
];

List<String> _allocationLabels(BuildContext context) => [
      context.tr("alloc_stock_market"),
      context.tr("alloc_tech"),
      context.tr("alloc_debt"),
      context.tr("alloc_money"),
      context.tr("alloc_asset"),
    ];

List<_Allocation> _allocationsFor(BuildContext context, double totalAmountPkr) => [
      _Allocation(
        context.tr("alloc_stock_market"),
        kStockMarketAllocationPercent,
        const Color(0xFF0F7A2C),
        stockSleeveAmountFromTotal(totalAmountPkr),
      ),
      _Allocation(
        context.tr("alloc_tech"),
        kTechAllocationPercent,
        const Color(0xFF2196F3),
        techSleeveAmountFromTotal(totalAmountPkr),
      ),
      _Allocation(
        context.tr("alloc_debt"),
        kDebtMarketAllocationPercent,
        const Color(0xFFFF9800),
        debtSleeveAmountFromTotal(totalAmountPkr),
      ),
      _Allocation(
        context.tr("alloc_money"),
        kMoneyMarketAllocationPercent,
        const Color(0xFF9C27B0),
        moneyMarketAmountFromAllocationTotal(totalAmountPkr),
      ),
      _Allocation(
        context.tr("alloc_asset"),
        kAlternativeAssetAllocationPercent,
        const Color(0xFFE91E63),
        digitalGoldSleeveAmountFromTotal(totalAmountPkr),
      ),
    ];

/// When [sleeves] matches snapshot order (stock→tech→debt→money→gold), labels
/// use [config] target %; PKR amounts stay on actual [SleeveBalanceEntry.displayPkr].
List<_Allocation> _allocationsMerged(
  BuildContext context,
  double totalAmountPkr,
  List<SleeveBalanceEntry>? sleeves,
  FiveMarketAllocations? config,
) {
  final labels = _allocationLabels(context);
  final configPcts = config != null
      ? [
          config.stock,
          config.tech,
          config.debt,
          config.money,
          config.gold,
        ]
      : null;

  if (sleeves != null && sleeves.length == 5) {
    final pos = sleeves
        .map((e) => e.displayPkr.isFinite && e.displayPkr > 0 ? e.displayPkr : 0.0)
        .toList();
    final sumPos = pos.fold(0.0, (a, b) => a + b);

    if (sumPos > 0 || configPcts != null) {
      return List<_Allocation>.generate(5, (i) {
        final displayPct = configPcts != null
            ? configPcts[i]
            : pos[i] / sumPos * 100;

        return _Allocation(
          labels[i],
          displayPct,
          _allocationColors[i],
          sleeves[i].displayPkr,
        );
      });
    }
  }

  if (configPcts != null) {
    return List<_Allocation>.generate(
      5,
      (i) => _Allocation(
        labels[i],
        configPcts[i],
        _allocationColors[i],
        totalAmountPkr * configPcts[i] / 100,
      ),
    );
  }

  return _allocationsFor(context, totalAmountPkr);
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
    this.sleeveEntries,
    this.configAllocations,
  });

  final double totalAmountPkr;
  final List<SleeveBalanceEntry>? sleeveEntries;
  final FiveMarketAllocations? configAllocations;

  @override
  State<AllocationPieChartWidget> createState() =>
      _AllocationPieChartWidgetState();
}

class _AllocationPieChartWidgetState extends State<AllocationPieChartWidget> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final allocations = _allocationsMerged(
      context,
      widget.totalAmountPkr,
      widget.sleeveEntries,
      widget.configAllocations,
    );
    final scheme = Theme.of(context).colorScheme;
    final se = widget.sleeveEntries;
    final mmPkr = (se != null && se.length == 5 && se[3].displayPkr.isFinite)
        ? se[3].displayPkr
        : moneyMarketAmountFromAllocationTotal(widget.totalAmountPkr);
    final useConfigSizing = widget.configAllocations != null;
    final pieSlices = useConfigSizing
        ? allocations.map((a) => a.pct).toList()
        : allocations
            .map((a) => a.amountPkr.isFinite && a.amountPkr > 0 ? a.amountPkr : 0.0)
            .toList();
    final pieSum = pieSlices.fold(0.0, (a, b) => a + b);

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
            clipBehavior: Clip.none,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
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
                    final v = pieSum > 0 ? pieSlices[i] : a.pct;
                    final pctLabel = a.pct.round();
                    return PieChartSectionData(
                      value: v,
                      color: a.color,
                      radius: isTouched ? 72 : 60,
                      title: "$pctLabel%",
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
                  width: 100,
                  height: 100,
                  padding: const EdgeInsets.all(8),
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
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.tr("alloc_money").toUpperCase(),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatMoney(mmPkr),
                          maxLines: 1,
                          softWrap: false,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr("total_investment_label"),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            fontSize: 8,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          _formatMoney(widget.totalAmountPkr),
                          maxLines: 1,
                          softWrap: false,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            fontSize: 8,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
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
                    "${allocation.pct.round()}%",
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
