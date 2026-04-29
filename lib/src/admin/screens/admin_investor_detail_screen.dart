import "package:cloud_functions/cloud_functions.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
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

class _InvestorDetailBody extends ConsumerStatefulWidget {
  const _InvestorDetailBody({
    required this.detail,
    required this.isDeleting,
    required this.onDelete,
  });

  final AdminInvestorDetail detail;
  final bool isDeleting;
  final VoidCallback onDelete;

  @override
  ConsumerState<_InvestorDetailBody> createState() =>
      _InvestorDetailBodyState();
}

class _InvestorDetailBodyState extends ConsumerState<_InvestorDetailBody> {
  final _overrideRateController = TextEditingController();
  bool _savingOverride = false;

  @override
  void dispose() {
    _overrideRateController.dispose();
    super.dispose();
  }

  Future<void> _saveOverride({
    required String uid,
    required bool enabled,
  }) async {
    final rate = double.tryParse(_overrideRateController.text.trim());
    if (rate == null || rate < 0 || rate > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter a valid investor annual rate (0–100)."),
        ),
      );
      return;
    }
    setState(() => _savingOverride = true);
    try {
      final adminUid =
          FirebaseAuth.instance.currentUser?.uid ?? "unknown_admin";
      await FirebaseFirestore.instance
          .collection("settings")
          .doc("returns_projection_overrides")
          .collection("items")
          .doc(uid)
          .set({
            "annualRatePct": rate,
            "enabled": enabled,
            "updatedAt": FieldValue.serverTimestamp(),
            "updatedBy": adminUid,
          }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Investor projection override saved.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save override: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingOverride = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.detail.summary;
    final wallet = widget.detail.wallet;
    final tx = widget.detail.transactions;
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
          Text(
            "UID: ${user.userId}",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text("Email: ${user.email.isEmpty ? "—" : user.email}"),
          Text("Phone: ${user.phone.isEmpty ? "—" : user.phone}"),
          if (isAdmin) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: widget.isDeleting ? null : widget.onDelete,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              icon: widget.isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              label: Text(
                widget.isDeleting
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
                value: currency.format(
                  widget.detail.totalInvestedFromTransactions,
                ),
                icon: Icons.analytics_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection("settings")
                .doc("returns_projection_overrides")
                .collection("items")
                .doc(user.userId)
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              final enabled = data?["enabled"] == true;
              final rate = (data?["annualRatePct"] as num?)?.toDouble() ?? 0.0;
              if (_overrideRateController.text.isEmpty) {
                _overrideRateController.text = rate.toStringAsFixed(2);
              }
              return Card(
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
                      Text(
                        "Live projection override",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Set investor-specific annual projection rate. "
                        "When enabled, this overrides global live projection.",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 280,
                        child: TextField(
                          controller: _overrideRateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: "Investor annual %",
                            hintText: "e.g. 30",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Enable investor override"),
                        value: enabled,
                        onChanged: _savingOverride
                            ? null
                            : (v) =>
                                  _saveOverride(uid: user.userId, enabled: v),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: _savingOverride
                              ? null
                              : () => _saveOverride(
                                  uid: user.userId,
                                  enabled: enabled,
                                ),
                          icon: _savingOverride
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _savingOverride
                                ? "Saving…"
                                : "Save investor override",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (isAdmin) ...[
            const SizedBox(height: 24),
            CrmAssignmentSection(investorUid: user.userId),
            const SizedBox(height: 24),
            _ReferrerCard(uid: user.userId),
          ],
          const SizedBox(height: 28),
          Text("Transactions", style: Theme.of(context).textTheme.titleLarge),
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
                  headingRowColor: WidgetStateProperty.all(
                    Colors.grey.shade100,
                  ),
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
                          DataCell(
                            Text(
                              t.createdAt != null
                                  ? dt.format(t.createdAt!.toLocal())
                                  : "—",
                            ),
                          ),
                          DataCell(Text(t.type)),
                          DataCell(Text(t.status)),
                          DataCell(Text(currency.format(t.amount))),
                          DataCell(
                            Text(t.notes?.isNotEmpty == true ? t.notes! : "—"),
                          ),
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

/// Referrer / Employee Commission record-keeping. The 2% referral fee is
/// already deducted automatically on the investor's first approved deposit
/// (per `settings/fee_config`). This card lets the admin attach metadata so
/// the company knows whom to pay out, and toggle a "paid" flag once that
/// off-platform settlement is completed.
class _ReferrerCard extends ConsumerStatefulWidget {
  const _ReferrerCard({required this.uid});
  final String uid;

  @override
  ConsumerState<_ReferrerCard> createState() => _ReferrerCardState();
}

class _ReferrerCardState extends ConsumerState<_ReferrerCard> {
  final _nameCtl = TextEditingController();
  final _noteCtl = TextEditingController();
  bool _payoutPaid = false;
  bool _saving = false;
  bool _hydrated = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  void _hydrate(Map<String, dynamic>? data) {
    if (_hydrated) return;
    _hydrated = true;
    final r = data?["referrerInfo"];
    if (r is Map) {
      _nameCtl.text = (r["referrerName"] as String?) ?? "";
      _noteCtl.text = (r["referrerNote"] as String?) ?? "";
      _payoutPaid = r["payoutPaid"] == true;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final adminUid =
          FirebaseAuth.instance.currentUser?.uid ?? "unknown_admin";
      await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.uid)
          .set({
        "referrerInfo": {
          "referrerName": _nameCtl.text.trim(),
          "referrerNote": _noteCtl.text.trim(),
          "payoutPaid": _payoutPaid,
          "updatedAt": FieldValue.serverTimestamp(),
          "updatedBy": adminUid,
        },
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("referrer_save_ok"))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${context.tr("referrer_save_failed")}: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        _hydrate(snapshot.data?.data());
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.handshake_outlined, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      context.tr("referrer_card_title"),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr("referrer_card_subtitle"),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtl,
                  decoration: InputDecoration(
                    labelText: context.tr("referrer_field_name"),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteCtl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.tr("referrer_field_note"),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _payoutPaid,
                  onChanged: (v) => setState(() => _payoutPaid = v),
                  title: Text(context.tr("referrer_payout_paid")),
                  subtitle: Text(
                    context.tr("referrer_payout_paid_subtitle"),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      _saving
                          ? context.tr("fee_saving")
                          : context.tr("referrer_save_action"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
