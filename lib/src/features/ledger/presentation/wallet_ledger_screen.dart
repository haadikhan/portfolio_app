import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../investment/data/allocation_money_market.dart";
import "../../../providers/wallet_providers.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);

String _formatTxTs(BuildContext context, dynamic v) {
  if (v is Timestamp) {
    return DateFormat.yMMMd().add_jm().format(v.toDate());
  }
  return context.tr("em_dash");
}

Color _stripeForType(String typeRaw) {
  final t = typeRaw.toLowerCase();
  if (t.contains("deposit")) return AppColors.dashboardDepositFg;
  if (t.contains("withdraw")) return AppColors.dashboardWithdrawFg;
  if (t.contains("profit") || t.contains("return")) {
    return AppColors.dashboardReportsFg;
  }
  return AppColors.primary;
}

class WalletLedgerScreen extends ConsumerStatefulWidget {
  const WalletLedgerScreen({super.key, this.initialTabIndex = 0});

  /// 0 wallet, 1 transactions, 2 history (grouped).
  final int initialTabIndex;

  @override
  ConsumerState<WalletLedgerScreen> createState() =>
      _WalletLedgerScreenState();
}

class _WalletLedgerScreenState extends ConsumerState<WalletLedgerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final i = widget.initialTabIndex.clamp(0, 2);
    _tabController = TabController(length: 3, vsync: this, initialIndex: i);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    ref.invalidate(userWalletStreamProvider);
    ref.invalidate(userTransactionsStreamProvider);
  }

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: TabBar(
                controller: _tabController,
                labelColor: scheme.primary,
                unselectedLabelColor: scheme.onSurfaceVariant,
                indicatorColor: scheme.primary,
                tabs: [
                  Tab(text: context.tr("ledger_tab_wallet")),
                  Tab(text: context.tr("ledger_tab_transactions")),
                  Tab(text: context.tr("ledger_tab_history")),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _WalletTab(
                    onRefresh: _onRefresh,
                  ),
                  _TransactionsOrHistoryTab(
                    onRefresh: _onRefresh,
                    groupByMonth: false,
                  ),
                  _TransactionsOrHistoryTab(
                    onRefresh: _onRefresh,
                    groupByMonth: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletTab extends ConsumerWidget {
  const _WalletTab({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(userWalletStreamProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
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
                    color:
                        scheme.surface.withValues(alpha: isDark ? 0.92 : 1),
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
              final allocationTotalPkr = allocationTotalFromWallet(w);
              final moneyMarketPkr = moneyMarketAvailableFromWallet(w);
              final avail =
                  (w["availableBalance"] as num?)?.toDouble() ?? 0;
              final reserved =
                  (w["reservedAmount"] as num?)?.toDouble() ?? 0;
              final td = (w["totalDeposited"] as num?)?.toDouble() ?? 0;
              final tw = (w["totalWithdrawn"] as num?)?.toDouble() ?? 0;
              final tp = (w["totalProfit"] as num?)?.toDouble() ?? 0;
              final ta = (w["totalAdjustments"] as num?)?.toDouble() ?? 0;
              final totalAllocationLine = _money.format(allocationTotalPkr);

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
                      context.tr("money_market_withdrawable_label"),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _money.format(moneyMarketPkr),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${context.tr("total_investment_label")}: $totalAllocationLine",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
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
        ],
      ),
    );
  }
}

class _TransactionsOrHistoryTab extends ConsumerWidget {
  const _TransactionsOrHistoryTab({
    required this.onRefresh,
    required this.groupByMonth,
  });

  final Future<void> Function() onRefresh;
  final bool groupByMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(userTransactionsStreamProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: txsAsync.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text("${context.tr("history_error")} $e"),
          ],
        ),
        data: (snap) {
          if (snap == null || snap.docs.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color:
                        scheme.surface.withValues(alpha: isDark ? 0.92 : 1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(
                    context.tr("no_transactions_yet"),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            );
          }

          final sorted =
              List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
            snap.docs,
          )..sort((a, b) {
              final ca = a.data()["createdAt"];
              final cb = b.data()["createdAt"];
              if (ca is! Timestamp) return 1;
              if (cb is! Timestamp) return -1;
              return cb.compareTo(ca);
            });

          final children = <Widget>[
            Text(
              groupByMonth
                  ? context.tr("ledger_tab_history")
                  : context.tr("transaction_history"),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
          ];

          if (groupByMonth) {
            String? lastMonth;
            var firstMonthHeader = true;
            for (final d in sorted) {
              final t = d.data()["createdAt"];
              final monthLabel = t is Timestamp
                  ? DateFormat.yMMMM().format(t.toDate())
                  : context.tr("em_dash");
              if (monthLabel != lastMonth) {
                lastMonth = monthLabel;
                children.add(
                  Padding(
                    padding: EdgeInsets.only(
                      top: firstMonthHeader ? 0 : 16,
                      bottom: 8,
                    ),
                    child: Text(
                      monthLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                );
                firstMonthHeader = false;
              }
              children.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LedgerTransactionCard(
                    doc: d,
                    scheme: scheme,
                    isDark: isDark,
                  ),
                ),
              );
            }
          } else {
            for (final d in sorted) {
              children.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LedgerTransactionCard(
                    doc: d,
                    scheme: scheme,
                    isDark: isDark,
                  ),
                ),
              );
            }
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: children,
          );
        },
      ),
    );
  }
}

class _LedgerTransactionCard extends StatelessWidget {
  const _LedgerTransactionCard({
    required this.doc,
    required this.scheme,
    required this.isDark,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final ColorScheme scheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final type = (m["type"] ?? "").toString();
    final status = (m["status"] ?? "").toString();
    final amt = (m["amount"] as num?)?.toDouble() ?? 0;
    final stripe = _stripeForType(type);

    return Material(
      color: scheme.surface.withValues(alpha: isDark ? 0.92 : 1),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      "${doc.id}\n$status · ${_formatTxTs(context, m["createdAt"])}",
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
