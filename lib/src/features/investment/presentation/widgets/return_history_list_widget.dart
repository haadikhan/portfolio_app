import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../../../core/theme/app_colors.dart";
import "../../../../models/return_history_model.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);
final _dateFmt = DateFormat("MMM yyyy");
final _pct = NumberFormat("+##0.00;-##0.00");

class ReturnHistoryListWidget extends StatelessWidget {
  const ReturnHistoryListWidget({super.key, required this.history});
  final List<ReturnHistoryModel> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            "No return history yet.",
            style: TextStyle(color: AppColors.bodyMuted, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: history.map((r) => _ReturnCard(record: r)).toList(),
    );
  }
}

class _ReturnCard extends StatelessWidget {
  const _ReturnCard({required this.record});
  final ReturnHistoryModel record;

  @override
  Widget build(BuildContext context) {
    final isPositive = record.returnPct >= 0;
    final color = isPositive ? AppColors.success : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Month badge
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat("MMM").format(record.appliedAt),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  DateFormat("yy").format(record.appliedAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dateFmt.format(record.appliedAt),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.heading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Profit: ${_money.format(record.profitAmount)}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.bodyMuted,
                  ),
                ),
              ],
            ),
          ),

          // Return pct
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${_pct.format(record.returnPct)}%",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  record.mode == "manual" ? "manual" : "auto",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
