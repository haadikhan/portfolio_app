import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../../../core/theme/app_colors.dart";
import "../../../../models/portfolio_model.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);
final _pct = NumberFormat("+##0.00;-##0.00");

class PerformanceMetricsWidget extends StatelessWidget {
  const PerformanceMetricsWidget({super.key, required this.portfolio});
  final PortfolioModel portfolio;

  @override
  Widget build(BuildContext context) {
    final totalReturn = portfolio.totalReturnPct;
    final netGain = portfolio.netGain;
    final lastPeriodPct = portfolio.lastMonthlyReturnPct;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: "Total return",
                value: "${_pct.format(totalReturn)}%",
                valueColor: totalReturn >= 0 ? AppColors.success : AppColors.error,
                icon: totalReturn >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: "Last period",
                value: "${_pct.format(lastPeriodPct)}%",
                valueColor:
                    lastPeriodPct >= 0 ? AppColors.success : AppColors.error,
                icon: Icons.calendar_month_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _MetricCard(
          label: "Net gain",
          value: _money.format(netGain),
          valueColor: netGain >= 0 ? AppColors.success : AppColors.error,
          icon: netGain >= 0
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded,
          wide: true,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
    this.wide = false,
  });
  final String label;
  final String value;
  final Color valueColor;
  final IconData icon;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: valueColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: valueColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.bodyMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
