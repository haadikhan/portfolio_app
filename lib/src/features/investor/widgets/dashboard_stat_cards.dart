import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../../core/theme/app_colors.dart";
import "../../../providers/dashboard_providers.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);

class DashboardStatCards extends StatelessWidget {
  const DashboardStatCards({super.key, required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final profitLoss = stats.profitLoss;
    final returnPct = stats.returnPct;

    return Column(
      children: [
        // ── Current Value hero card ────────────────────────────────────
        _CurrentValueCard(
          currentValue: stats.currentValue,
          totalDeposited: stats.totalDeposited,
        ),
        const SizedBox(height: 12),

        // ── Bottom row: 3 metric cards ─────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.account_balance_wallet_outlined,
                label: "Total Invested",
                value: _money.format(stats.totalDeposited),
                valueColor: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: profitLoss >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                label: "Profit / Loss",
                value: _formatSigned(profitLoss),
                valueColor: profitLoss > 0
                    ? AppColors.success
                    : profitLoss < 0
                        ? AppColors.error
                        : AppColors.bodyMuted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.percent_rounded,
                label: "Total Return",
                value: returnPct == null
                    ? "—"
                    : "${returnPct >= 0 ? "+" : ""}${returnPct.toStringAsFixed(1)}%",
                valueColor: returnPct == null
                    ? AppColors.bodyMuted
                    : returnPct >= 0
                        ? AppColors.success
                        : AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatSigned(double v) {
    if (v == 0) return "PKR 0";
    return "${v > 0 ? "+" : ""}${_money.format(v)}";
  }
}

// ── Current Value hero card ───────────────────────────────────────────────────

class _CurrentValueCard extends StatelessWidget {
  const _CurrentValueCard({
    required this.currentValue,
    required this.totalDeposited,
  });
  final double currentValue;
  final double totalDeposited;

  @override
  Widget build(BuildContext context) {
    final gain = currentValue - totalDeposited;
    final isPositive = gain >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D6B26), AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Current Value",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _money.format(currentValue),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (isPositive ? Colors.greenAccent : Colors.redAccent)
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isPositive ? Colors.greenAccent : Colors.redAccent)
                    .withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPositive
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 13,
                  color: isPositive ? Colors.greenAccent : Colors.redAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  gain == 0
                      ? "No change"
                      : "${isPositive ? "+" : ""}${_money.format(gain)}",
                  style: TextStyle(
                    color: isPositive ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

// ── Small stat card ───────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: valueColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: valueColor),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.bodyMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
