import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../providers/wallet_providers.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);

class WalletLedgerScreen extends ConsumerWidget {
  const WalletLedgerScreen({super.key});

  static String _ts(BuildContext context, dynamic v) {
    if (v is Timestamp) {
      return DateFormat.yMMMd().add_jm().format(v.toDate());
    }
    return context.tr("em_dash");
  }

  static Color _stripeForType(String typeRaw) {
    final t = typeRaw.toLowerCase();
    if (t.contains("deposit")) return AppColors.dashboardDepositFg;
    if (t.contains("withdraw")) return AppColors.dashboardWithdrawFg;
    if (t.contains("profit") || t.contains("return")) {
      return AppColors.dashboardReportsFg;
    }
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(userWalletStreamProvider);
    final txsAsync = ref.watch(userTransactionsStreamProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageGradient = isDark
        ? [scheme.surface, scheme.surfaceContainerLowest]
        : [AppColors.backgroundTop, AppColors.backgroundBottom];

    return AppScaffold(
      title: context.tr("wallet_ledger_title"),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: pageGradient,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userWalletStreamProvider);
            ref.invalidate(userTransactionsStreamProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              walletAsync.when(
                loading: () => Container(
                  height: 160,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: isDark ? 0.92 : 1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: const CircularProgressIndicator(),
                ),
                error: (e, _) => Text("${context.tr("wallet_error")} $e"),
                data: (w) {
                  if (w == null) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: isDark ? 0.92 : 1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr("no_wallet_data"),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr("no_wallet_subtitle"),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  }
                  final current = (w["currentBalance"] as num?)?.toDouble() ?? 0;
                  final avail =
                      (w["availableBalance"] as num?)?.toDouble() ?? 0;
                  final reserved =
                      (w["reservedAmount"] as num?)?.toDouble() ?? 0;
                  final td = (w["totalDeposited"] as num?)?.toDouble() ?? 0;
                  final tw = (w["totalWithdrawn"] as num?)?.toDouble() ?? 0;
                  final tp = (w["totalProfit"] as num?)?.toDouble() ?? 0;
                  final ta = (w["totalAdjustments"] as num?)?.toDouble() ?? 0;

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.28),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr("current_balance"),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _money.format(current),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _WalletMiniStat(
                                label: context.tr("available"),
                                value: _money.format(avail),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 36,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            Expanded(
                              child: _WalletMiniStat(
                                label: context.tr("reserved_withdrawals"),
                                value: _money.format(reserved),
                                align: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr("totals"),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "${context.tr("totals_line_deposited")} ${_money.format(td)}\n"
                          "${context.tr("totals_line_withdrawn")} ${_money.format(tw)}\n"
                          "${context.tr("totals_line_profit")} ${_money.format(tp)}\n"
                          "${context.tr("totals_line_adjustments")} ${_money.format(ta)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.dashboardDepositFg,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => context.push("/wallet-ledger/deposit"),
                      child: Text(context.tr("deposit_request")),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.dashboardWithdrawFg,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => context.push("/wallet-ledger/withdraw"),
                      child: Text(context.tr("withdrawal_request_btn")),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                context.tr("transaction_history"),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),
              txsAsync.when(
                loading: () => Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: isDark ? 0.92 : 1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text("${context.tr("history_error")} $e"),
                data: (snap) {
                  if (snap == null || snap.docs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: isDark ? 0.92 : 1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Text(
                        context.tr("no_transactions_yet"),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  }
                  return Column(
                    children: snap.docs.map((d) {
                      final m = d.data();
                      final type = (m["type"] ?? "").toString();
                      final status = (m["status"] ?? "").toString();
                      final amt = (m["amount"] as num?)?.toDouble() ?? 0;
                      final stripe = _stripeForType(type);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: scheme.surface.withValues(
                            alpha: isDark ? 0.92 : 1,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: scheme.outlineVariant),
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  width: 4,
                                  decoration: BoxDecoration(
                                    color: stripe,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(14),
                                      bottomLeft: Radius.circular(14),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                type.toUpperCase(),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                  color: scheme.onSurface,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _money.format(amt),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: stripe,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          "${d.id}\n$status · ${_ts(context, m["createdAt"])}",
                                          style: TextStyle(
                                            fontSize: 11,
                                            height: 1.35,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletMiniStat extends StatelessWidget {
  const _WalletMiniStat({
    required this.label,
    required this.value,
    this.align = TextAlign.left,
  });
  final String label;
  final String value;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: align == TextAlign.center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            textAlign: align,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: align,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
