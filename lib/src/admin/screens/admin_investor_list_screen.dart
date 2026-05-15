import "package:cloud_functions/cloud_functions.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../core/i18n/app_translations.dart";
import "../models/admin_investor_models.dart";
import "../providers/admin_providers.dart";
import "../providers/five_market_admin_providers.dart";
import "../services/five_market_admin_service.dart";

class AdminInvestorListScreen extends ConsumerStatefulWidget {
  const AdminInvestorListScreen({super.key});

  @override
  ConsumerState<AdminInvestorListScreen> createState() =>
      _AdminInvestorListScreenState();
}

class _AdminInvestorListScreenState extends ConsumerState<AdminInvestorListScreen> {
  late final TextEditingController _searchController;
  String? _ledgerSavingUid;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSetLedger(String userId, bool enabled) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr("admin_five_market_ledger_confirm_title")),
        content: Text(
          enabled
              ? context.tr("admin_five_market_ledger_confirm_body_enable")
              : context.tr("admin_five_market_ledger_confirm_body_disable"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr("cancel")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr("save_btn")),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _ledgerSavingUid = userId);
    try {
      await ref.read(fiveMarketAdminServiceProvider).setDailyLedger(
            userId: userId,
            enabled: enabled,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("admin_five_market_ledger_saved"))),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${context.tr("admin_five_market_ledger_save_failed")}: "
            "${fiveMarketAdminCallableErrorMessage(e)}",
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${context.tr("admin_five_market_ledger_save_failed")}: $e",
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _ledgerSavingUid = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final async = ref.watch(filteredInvestorsProvider);
    final query = ref.watch(investorSearchQueryProvider);
    final ledgerMap = ref.watch(adminPortfolioLedgerMapProvider).valueOrNull ??
        const <String, bool>{};
    if (_searchController.text != query) {
      _searchController.text = query;
      _searchController.selection =
          TextSelection.collapsed(offset: _searchController.text.length);
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Investors",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            "View all investors and inspect full financial profile.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextField(
            onChanged: (v) =>
                ref.read(investorSearchQueryProvider.notifier).state = v,
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search by name, email, or phone",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => ref
                          .read(investorSearchQueryProvider.notifier)
                          .state = "",
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Error: $e")),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text("No investors found for current search."),
                  );
                }
                return _InvestorTable(
                  items: items,
                  ledgerMap: ledgerMap,
                  ledgerSavingUid: _ledgerSavingUid,
                  onLedgerChanged: _confirmAndSetLedger,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InvestorTable extends StatelessWidget {
  const _InvestorTable({
    required this.items,
    required this.ledgerMap,
    required this.ledgerSavingUid,
    required this.onLedgerChanged,
  });

  final List<AdminInvestorSummary> items;
  final Map<String, bool> ledgerMap;
  final String? ledgerSavingUid;
  final Future<void> Function(String userId, bool enabled) onLedgerChanged;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          columns: [
            const DataColumn(label: Text("Investor")),
            const DataColumn(label: Text("Email")),
            const DataColumn(label: Text("Phone")),
            const DataColumn(label: Text("KYC")),
            const DataColumn(label: Text("Joined")),
            DataColumn(
              label: Text(context.tr("admin_investor_list_col_ledger")),
            ),
            const DataColumn(label: Text("")),
          ],
          rows: [
            for (final i in items)
              DataRow(
                cells: [
                  DataCell(Text(i.name.isNotEmpty ? i.name : i.userId)),
                  DataCell(Text(i.email.isNotEmpty ? i.email : "—")),
                  DataCell(Text(i.phone.isNotEmpty ? i.phone : "—")),
                  DataCell(
                    Chip(
                      label: Text(i.kycStatus),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  DataCell(
                    Text(
                      i.createdAt != null
                          ? fmt.format(i.createdAt!.toLocal())
                          : "—",
                    ),
                  ),
                  DataCell(
                    ledgerSavingUid == i.userId
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Switch(
                            value: ledgerMap[i.userId] ?? false,
                            onChanged: (v) => onLedgerChanged(i.userId, v),
                          ),
                  ),
                  DataCell(
                    FilledButton(
                      onPressed: () => context.go("/investors/${i.userId}"),
                      child: const Text("View"),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
