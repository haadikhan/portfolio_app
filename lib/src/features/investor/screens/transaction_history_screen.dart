import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/i18n/app_translations.dart";
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

  final _typeFilters = ["all", "deposit", "withdrawal", "profit_entry", "fees"];

  static const _kFeeTypes = <String>{
    "front_end_load_fee",
    "referral_fee",
    "management_fee",
    "performance_fee",
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<TxnItem> _filter(List<TxnItem> all, int tabIndex) {
    List<TxnItem> result = all;

    final typeFilter = _typeFilters[tabIndex];
    if (typeFilter == "fees") {
      result = result.where((t) => _kFeeTypes.contains(t.type)).toList();
    } else if (typeFilter != "all") {
      result = result
          .where((t) =>
              t.type == typeFilter ||
              (typeFilter == "profit_entry" && t.type == "profit"))
          .toList();
    }

    if (_statusFilter != "all") {
      result = result.where((t) => t.status == _statusFilter).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final txnsAsync = ref.watch(userTransactionItemsProvider);
    final scheme = Theme.of(context).colorScheme;

    final tabs = [
      Tab(text: context.tr("tab_all")),
      Tab(text: context.tr("tab_deposits")),
      Tab(text: context.tr("tab_withdrawals")),
      Tab(text: context.tr("tab_profit")),
      Tab(text: context.tr("tab_fees")),
    ];

    return AppScaffold(
      title: context.tr("txn_history_title"),
      body: Column(
        children: [
          Container(
            color: scheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _StatusChip(
                    label: context.tr("tab_all"),
                    active: _statusFilter == "all",
                    onTap: () => setState(() => _statusFilter = "all"),
                  ),
                  const SizedBox(width: 6),
                  _StatusChip(
                    label: context.tr("filter_pending"),
                    active: _statusFilter == "pending",
                    color: AppColors.warning,
                    onTap: () => setState(() => _statusFilter = "pending"),
                  ),
                  const SizedBox(width: 6),
                  _StatusChip(
                    label: context.tr("filter_approved"),
                    active: _statusFilter == "approved",
                    color: AppColors.success,
                    onTap: () => setState(() => _statusFilter = "approved"),
                  ),
                  const SizedBox(width: 6),
                  _StatusChip(
                    label: context.tr("filter_rejected"),
                    active: _statusFilter == "rejected",
                    color: AppColors.error,
                    onTap: () => setState(() => _statusFilter = "rejected"),
                  ),
                ],
              ),
            ),
          ),
          Container(
            color: scheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: scheme.primary,
              unselectedLabelColor: scheme.onSurfaceVariant,
              indicatorColor: scheme.primary,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              tabs: tabs,
            ),
          ),
          Expanded(
            child: txnsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  "${context.tr("error_prefix")} $e",
                  style: TextStyle(color: scheme.error),
                ),
              ),
              data: (all) => TabBarView(
                controller: _tabController,
                children: List.generate(5, (i) {
                  final items = _filter(all, i);
                  if (items.isEmpty) {
                    return _EmptyState(statusFilter: _statusFilter);
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

class TransactionRowItem extends StatelessWidget {
  const TransactionRowItem({super.key, required this.txn});
  final TxnItem txn;

  static const _kFeeTypes = <String>{
    "front_end_load_fee",
    "referral_fee",
    "management_fee",
    "performance_fee",
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDeposit = txn.type == "deposit";
    final isProfit =
        txn.type == "profit_entry" || txn.type == "profit";
    final isWithdrawal = txn.type == "withdrawal";
    final isFee = _kFeeTypes.contains(txn.type);

    final (Color iconBg, Color iconFg, IconData icon) = isDeposit
        ? (
            scheme.primaryContainer.withValues(alpha: 0.5),
            AppColors.success,
            Icons.arrow_downward_rounded
          )
        : isWithdrawal
            ? (
                scheme.errorContainer.withValues(alpha: 0.45),
                AppColors.error,
                Icons.arrow_upward_rounded
              )
            : isFee
                ? (
                    scheme.errorContainer.withValues(alpha: 0.4),
                    AppColors.error,
                    _feeIcon(txn.type),
                  )
                : (
                    scheme.primaryContainer.withValues(alpha: 0.4),
                    Colors.blue.shade700,
                    Icons.trending_up_rounded,
                  );

    final amountColor = isDeposit || isProfit ? AppColors.success : AppColors.error;
    final amountSign = isDeposit || isProfit ? "+" : "-";

    final typeLabel = isDeposit
        ? context.tr("txn_type_deposit")
        : isWithdrawal
            ? context.tr("txn_type_withdrawal")
            : isFee
                ? _feeLabel(context, txn.type)
                : context.tr("txn_type_profit");

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _dateFmt.format(txn.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (txn.paymentMethod != null &&
                    txn.paymentMethod!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    txn.paymentMethod!,
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
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

  IconData _feeIcon(String ty) {
    switch (ty) {
      case "front_end_load_fee":
        return Icons.input_rounded;
      case "referral_fee":
        return Icons.handshake_outlined;
      case "management_fee":
        return Icons.account_balance_outlined;
      case "performance_fee":
        return Icons.trending_up_rounded;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  String _feeLabel(BuildContext context, String ty) {
    switch (ty) {
      case "front_end_load_fee":
        return context.tr("fee_label_front_load");
      case "referral_fee":
        return context.tr("fee_label_referral");
      case "management_fee":
        return context.tr("fee_label_management");
      case "performance_fee":
        return context.tr("fee_label_performance");
      default:
        return context.tr("txn_type_fee");
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (status) {
      "approved" => (
          scheme.primaryContainer.withValues(alpha: 0.5),
          AppColors.success
        ),
      "rejected" => (
          scheme.errorContainer.withValues(alpha: 0.45),
          AppColors.error
        ),
      _ => (
          scheme.secondaryContainer.withValues(alpha: 0.35),
          AppColors.warning
        ),
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
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.12) : scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? c : scheme.outlineVariant,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? c : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.statusFilter});
  final String statusFilter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final msg = statusFilter == "all"
        ? context.tr("txn_empty_generic")
        : context.tr("txn_empty_filtered");
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            msg,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
