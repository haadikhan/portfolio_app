import "package:cloud_functions/cloud_functions.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../core/i18n/app_translations.dart";
import "../crm/crm_assignment_section.dart";
import "../models/admin_investor_models.dart";
import "../providers/admin_providers.dart";

class AdminInvestorDetailScreen extends ConsumerStatefulWidget {
  const AdminInvestorDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<AdminInvestorDetailScreen> createState() =>
      _AdminInvestorDetailScreenState();
}

class _AdminInvestorDetailScreenState
    extends ConsumerState<AdminInvestorDetailScreen> {
  bool _isDeleting = false;

  Future<void> _deleteInvestor(AdminInvestorDetail detail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr("admin_investor_delete_title")),
        content: Text(context.tr("admin_investor_delete_confirm_body")),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr("cancel")),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(context.tr("admin_investor_delete_action")),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      final fn = FirebaseFunctions.instanceFor(region: "us-central1");
      await fn.httpsCallable("deleteInvestorAccount").call({
        "userId": detail.summary.userId,
      });
      ref.invalidate(allInvestorsProvider);
      ref.invalidate(investorDetailProvider(detail.summary.userId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("admin_investor_delete_success"))),
      );
      context.go("/investors");
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final message = e.message?.trim().isNotEmpty == true
          ? e.message!
          : context.tr("admin_investor_delete_error");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("admin_investor_delete_error"))),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final async = ref.watch(investorDetailProvider(widget.userId));
    return Padding(
      padding: const EdgeInsets.all(24),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
        data: (detail) {
          if (detail == null) {
            return Center(child: Text(context.tr("admin_investor_not_found")));
          }
          return _InvestorDetailBody(
            detail: detail,
            isDeleting: _isDeleting,
            onDelete: () => _deleteInvestor(detail),
          );
        },
      ),
    );
  }
}

class _InvestorDetailBody extends ConsumerWidget {
  const _InvestorDetailBody({
    required this.detail,
    required this.isDeleting,
    required this.onDelete,
  });

  final AdminInvestorDetail detail;
  final bool isDeleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = detail.summary;
    final wallet = detail.wallet;
    final tx = detail.transactions;
    final currency = NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);
    final dt = DateFormat.yMMMd().add_Hm();
    final role = ref.watch(adminRoleProvider).valueOrNull ?? "";
    final isAdmin = role.toLowerCase() == "admin";

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.go("/investors"),
            icon: const Icon(Icons.arrow_back),
            label: const Text("Investors"),
          ),
          const SizedBox(height: 8),
          Text(
            user.name.isNotEmpty ? user.name : user.userId,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text("UID: ${user.userId}", style: Theme.of(context).textTheme.bodySmall),
          Text("Email: ${user.email.isEmpty ? "—" : user.email}"),
          Text("Phone: ${user.phone.isEmpty ? "—" : user.phone}"),
          if (isAdmin) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isDeleting ? null : onDelete,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              icon: isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              label: Text(
                isDeleting
                    ? context.tr("admin_investor_delete_in_progress")
                    : context.tr("admin_investor_delete_action"),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _MetricCard(
                title: "KYC Status",
                value: user.kycStatus,
                icon: Icons.badge_outlined,
              ),
              _MetricCard(
                title: "Total Deposited",
                value: currency.format(wallet.totalDeposited),
                icon: Icons.south_west_outlined,
              ),
              _MetricCard(
                title: "Total Withdrawn",
                value: currency.format(wallet.totalWithdrawn),
                icon: Icons.north_east_outlined,
              ),
              _MetricCard(
                title: "Profit",
                value: currency.format(wallet.totalProfit),
                icon: Icons.trending_up,
              ),
              _MetricCard(
                title: "Current Balance",
                value: currency.format(wallet.balance),
                icon: Icons.account_balance_wallet_outlined,
              ),
              _MetricCard(
                title: "Invested (from ledger)",
                value: currency.format(detail.totalInvestedFromTransactions),
                icon: Icons.analytics_outlined,
              ),
            ],
          ),
          if (isAdmin) ...[
            const SizedBox(height: 24),
            CrmAssignmentSection(investorUid: user.userId),
          ],
          const SizedBox(height: 28),
          Text(
            "Transactions",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (tx.isEmpty)
            const Text("No transactions found.")
          else
            Card(
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
                  columns: const [
                    DataColumn(label: Text("Date")),
                    DataColumn(label: Text("Type")),
                    DataColumn(label: Text("Status")),
                    DataColumn(label: Text("Amount")),
                    DataColumn(label: Text("Notes")),
                  ],
                  rows: [
                    for (final t in tx)
                      DataRow(
                        cells: [
                          DataCell(Text(
                            t.createdAt != null
                                ? dt.format(t.createdAt!.toLocal())
                                : "—",
                          )),
                          DataCell(Text(t.type)),
                          DataCell(Text(t.status)),
                          DataCell(Text(currency.format(t.amount))),
                          DataCell(Text(t.notes?.isNotEmpty == true ? t.notes! : "—")),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}
