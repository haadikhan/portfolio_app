import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../providers/transaction_history_providers.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);
final _dateFmt = DateFormat("MMM d, yyyy");

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _statusFilter = "all";

  final _tabs = const [
    Tab(text: "All"),
    Tab(text: "Deposits"),
    Tab(text: "Withdrawals"),
    Tab(text: "Profit"),
  ];

  final _typeFilters = ["all", "deposit", "withdrawal", "profit_entry"];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<TxnItem> _filter(List<TxnItem> all, int tabIndex) {
    List<TxnItem> result = all;

    // Type filter
    final typeFilter = _typeFilters[tabIndex];
    if (typeFilter != "all") {
      result = result
          .where((t) =>
              t.type == typeFilter ||
              (typeFilter == "profit_entry" && t.type == "profit"))
          .toList();
    }

    // Status filter
    if (_statusFilter != "all") {
      result = result.where((t) => t.status == _statusFilter).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final txnsAsync = ref.watch(userTransactionItemsProvider);

    return AppScaffold(
      title: "Transaction history",
      body: Column(
        children: [
          // ── Status filter chips ──────────────────────────────────────
          Container(
            color: AppColors.backgroundTop,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _StatusChip(
                    label: "All",
                    active: _statusFilter == "all",
                    onTap: () => setState(() => _statusFilter = "all"),
                  ),
                  const SizedBox(width: 6),
                  _StatusChip(
                    label: "Pending",
                    active: _statusFilter == "pending",
                    color: AppColors.warning,
                    onTap: () => setState(() => _statusFilter = "pending"),
                  ),
                  const SizedBox(width: 6),
                  _StatusChip(
                    label: "Approved",
                    active: _statusFilter == "approved",
                    color: AppColors.success,
                    onTap: () => setState(() => _statusFilter = "approved"),
                  ),
                  const SizedBox(width: 6),
                  _StatusChip(
                    label: "Rejected",
                    active: _statusFilter == "rejected",
                    color: AppColors.error,
                    onTap: () => setState(() => _statusFilter = "rejected"),
                  ),
                ],
              ),
            ),
          ),

          // ── Type tab bar ─────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.bodyMuted,
              indicatorColor: AppColors.primary,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              tabs: _tabs,
            ),
          ),

          // ── List ─────────────────────────────────────────────────────
          Expanded(
            child: txnsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text("Error: $e", style: const TextStyle(color: AppColors.error))),
              data: (all) => TabBarView(
                controller: _tabController,
                children: List.generate(4, (i) {
                  final items = _filter(all, i);
                  if (items.isEmpty) {
                    return _EmptyState(
                        tabIndex: i, statusFilter: _statusFilter);
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(userTransactionItemsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) =>
                          TransactionRowItem(txn: items[idx]),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transaction row item ──────────────────────────────────────────────────────

class TransactionRowItem extends StatelessWidget {
  const TransactionRowItem({super.key, required this.txn});
  final TxnItem txn;

  @override
  Widget build(BuildContext context) {
    final isDeposit = txn.type == "deposit";
    final isProfit =
        txn.type == "profit_entry" || txn.type == "profit";
    final isWithdrawal = txn.type == "withdrawal";

    final (Color iconBg, Color iconFg, IconData icon) = isDeposit
        ? (
            const Color(0xFFE8F5E9),
            AppColors.success,
            Icons.arrow_downward_rounded
          )
        : isWithdrawal
            ? (
                const Color(0xFFFFEBEE),
                AppColors.error,
                Icons.arrow_upward_rounded
              )
            : (
                const Color(0xFFE3F2FD),
                Colors.blue.shade700,
                Icons.trending_up_rounded
              );

    final amountColor = isDeposit || isProfit ? AppColors.success : AppColors.error;
    final amountSign = isDeposit || isProfit ? "+" : "-";

    final typeLabel = isDeposit
        ? "Deposit"
        : isWithdrawal
            ? "Withdrawal"
            : "Profit entry";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // ── Icon ─────────────────────────────────────────────────
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconFg, size: 18),
          ),
          const SizedBox(width: 12),

          // ── Info ─────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.heading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _dateFmt.format(txn.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.bodyMuted,
                  ),
                ),
                if (txn.paymentMethod != null &&
                    txn.paymentMethod!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    txn.paymentMethod!,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.bodyMuted),
                  ),
                ],
              ],
            ),
          ),

          // ── Amount + badge ───────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "$amountSign${_money.format(txn.amount)}",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
              const SizedBox(height: 4),
              _StatusBadge(status: txn.status),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      "approved" => (const Color(0xFFE8F5E9), AppColors.success),
      "rejected" => (const Color(0xFFFFEBEE), AppColors.error),
      _ => (const Color(0xFFFFF8E1), AppColors.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

// ── Status chip (filter) ──────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.color,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? c : AppColors.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? c : AppColors.bodyMuted,
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tabIndex, required this.statusFilter});
  final int tabIndex;
  final String statusFilter;

  @override
  Widget build(BuildContext context) {
    final typeLabels = ["transactions", "deposits", "withdrawals", "profit entries"];
    final type = typeLabels[tabIndex];
    final msg = statusFilter == "all"
        ? "No $type yet"
        : "No $statusFilter $type";
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 48, color: AppColors.bodyMuted),
          const SizedBox(height: 12),
          Text(
            msg,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.bodyMuted,
            ),
          ),
        ],
      ),
    );
  }
}
