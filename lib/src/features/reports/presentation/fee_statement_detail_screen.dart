import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../data/fee_statement_providers.dart";

/// Premium banking-app style monthly fee statement.
class FeeStatementDetailScreen extends StatelessWidget {
  const FeeStatementDetailScreen({super.key, required this.statement});
  final FeeStatement statement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);

    final monthLabel = _formatPeriodMonth(statement.periodKey);
    final transparent = statement.totalFees > 0 || statement.netProfit > 0;

    final pageGradient = isDark
        ? [scheme.surface, scheme.surfaceContainerLowest]
        : [AppColors.backgroundTop, AppColors.backgroundBottom];

    return AppScaffold(
      title: context.tr("fee_statement_screen_title"),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: pageGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeroCard(monthLabel: monthLabel, statement: statement),
            const SizedBox(height: 16),
            _SummarySection(statement: statement, money: money),
            const SizedBox(height: 16),
            if (transparent) _TransparencyNote(),
          ],
        ),
      ),
    );
  }

  String _formatPeriodMonth(String yyyyMM) {
    final parts = yyyyMM.split("-");
    if (parts.length != 2) return yyyyMM;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null) return yyyyMM;
    return DateFormat.yMMMM().format(DateTime(y, m));
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.monthLabel, required this.statement});
  final String monthLabel;
  final FeeStatement statement;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr("fee_statement_screen_title"),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      monthLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${statement.effectiveFeeRatePct.toStringAsFixed(1)}%",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            context.tr("fee_statement_net_credited"),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            money.format(statement.netProfit),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: context.tr("fee_statement_principal"),
                  value: money.format(statement.principalAtStart),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroStat(
                  label: context.tr("fee_statement_total_fees"),
                  value: money.format(statement.totalFees),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.statement, required this.money});
  final FeeStatement statement;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final rows = <_LineItem>[
      _LineItem(
        icon: Icons.south_west_rounded,
        accent: Colors.green.shade700,
        label: context.tr("fee_statement_gross_profit"),
        amount: statement.grossProfit,
        sign: "+",
      ),
      if (statement.performanceFee > 0)
        _LineItem(
          icon: Icons.trending_up_rounded,
          accent: const Color(0xFF00897B),
          label: context.tr("fee_label_performance"),
          amount: statement.performanceFee,
          sign: "-",
        ),
      if (statement.managementFee > 0)
        _LineItem(
          icon: Icons.account_balance_outlined,
          accent: const Color(0xFF1E88E5),
          label: context.tr("fee_label_management"),
          amount: statement.managementFee,
          sign: "-",
        ),
      if (statement.frontEndLoadFee > 0)
        _LineItem(
          icon: Icons.input_rounded,
          accent: const Color(0xFF6A1B9A),
          label: context.tr("fee_label_front_load"),
          amount: statement.frontEndLoadFee,
          sign: "-",
        ),
      if (statement.referralFee > 0)
        _LineItem(
          icon: Icons.handshake_outlined,
          accent: const Color(0xFFEF6C00),
          label: context.tr("fee_label_referral"),
          amount: statement.referralFee,
          sign: "-",
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr("fee_statement_breakdown"),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++) ...[
            _LineItemRow(item: rows[i], money: money),
            if (i != rows.length - 1)
              Divider(
                height: 16,
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.savings_rounded,
                  color: scheme.onPrimaryContainer,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr("fee_statement_net_credited"),
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  "+ ${money.format(statement.netProfit)}",
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          if (statement.depositsThisMonth > 0 ||
              statement.withdrawalsThisMonth > 0) ...[
            const SizedBox(height: 14),
            Text(
              context.tr("fee_statement_activity"),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            if (statement.depositsThisMonth > 0)
              _ActivityRow(
                label: context.tr("fee_statement_deposits_month"),
                value: "+ ${money.format(statement.depositsThisMonth)}",
                color: Colors.green.shade700,
              ),
            if (statement.withdrawalsThisMonth > 0)
              _ActivityRow(
                label: context.tr("fee_statement_withdrawals_month"),
                value: "- ${money.format(statement.withdrawalsThisMonth)}",
                color: Colors.red.shade700,
              ),
          ],
        ],
      ),
    );
  }
}

class _LineItem {
  const _LineItem({
    required this.icon,
    required this.accent,
    required this.label,
    required this.amount,
    required this.sign,
  });
  final IconData icon;
  final Color accent;
  final String label;
  final double amount;
  final String sign;
}

class _LineItemRow extends StatelessWidget {
  const _LineItemRow({required this.item, required this.money});
  final _LineItem item;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: item.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(item.icon, color: item.accent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            item.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ),
        Text(
          "${item.sign} ${money.format(item.amount)}",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: item.sign == "+"
                ? Colors.green.shade700
                : scheme.error,
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransparencyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: scheme.onSecondaryContainer, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr("fee_statement_transparency_note"),
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSecondaryContainer,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
