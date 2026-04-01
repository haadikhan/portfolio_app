import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../providers/admin_finance_providers.dart";
import "../../../providers/auth_providers.dart";
import "../../../providers/wallet_providers.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);

/// Queues, ledger explorer, and manual postings (admin-only; enforced server-side).
class AdminFinanceConsoleScreen extends ConsumerStatefulWidget {
  const AdminFinanceConsoleScreen({super.key});

  @override
  ConsumerState<AdminFinanceConsoleScreen> createState() =>
      _AdminFinanceConsoleScreenState();
}

class _AdminFinanceConsoleScreenState extends ConsumerState<AdminFinanceConsoleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    return profile.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text("$e"))),
      data: (u) {
        if (u == null || !u.isAdmin) {
          return Scaffold(
            appBar: AppBar(title: const Text("Finance console")),
            body: const Center(
              child: Text("Admin access required."),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text("Finance console"),
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabs: const [
                Tab(text: "Deposits"),
                Tab(text: "Withdrawals"),
                Tab(text: "Ledger"),
                Tab(text: "Audit"),
                Tab(text: "Manual"),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: const [
              _DepositQueueTab(),
              _WithdrawalQueueTab(),
              _LedgerTab(),
              _AuditTab(),
              _ManualPostingsTab(),
            ],
          ),
        );
      },
    );
  }
}

class _DepositQueueTab extends ConsumerWidget {
  const _DepositQueueTab();

  static String _ts(dynamic v) {
    if (v is Timestamp) {
      return DateFormat.yMMMd().add_jm().format(v.toDate());
    }
    return "—";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminPendingDepositsStreamProvider);
    final reviewed = ref.watch(adminReviewedDepositsStreamProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("$e")),
      data: (snap) {
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text("Pending", style: Theme.of(context).textTheme.titleMedium),
            if (snap.docs.isEmpty) const Text("No pending deposits."),
            ...snap.docs.map((doc) {
              final m = doc.data();
              final uid = (m["userId"] ?? "").toString();
              final amt = (m["amount"] as num?)?.toDouble() ?? 0;
              final proof = m["proofUrl"] as String?;
              return Card(
                child: ExpansionTile(
                  title: Text(_money.format(amt)),
                  subtitle: Text("User: $uid\n${_ts(m["createdAt"])}"),
                  children: [
                    if (proof != null && proof.isNotEmpty)
                      ListTile(
                        title: const Text("Proof"),
                        subtitle: SelectableText(proof),
                      ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => _approveDeposit(context, ref, doc.id),
                          child: const Text("Approve"),
                        ),
                        TextButton(
                          onPressed: () => _rejectDeposit(context, ref, doc.id),
                          child: const Text("Reject"),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
            Text("Reviewed", style: Theme.of(context).textTheme.titleMedium),
            reviewed.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text("$e"),
              data: (revSnap) {
                if (revSnap.docs.isEmpty) return const Text("No reviewed deposits yet.");
                return Column(
                  children: revSnap.docs.map((doc) {
                    final m = doc.data();
                    final uid = (m["userId"] ?? "").toString();
                    final amt = (m["amount"] as num?)?.toDouble() ?? 0;
                    final status = (m["status"] ?? "").toString();
                    return Card(
                      child: ListTile(
                        title: Text(_money.format(amt)),
                        subtitle: Text("User: $uid · $status · ${_ts(m["updatedAt"])}"),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _approveDeposit(BuildContext context, WidgetRef ref, String id) async {
    final note = await _promptNote(context, title: "Approve deposit", hint: "Optional note");
    if (note == null) return;
    try {
      await ref.read(walletLedgerFunctionsProvider).approveDeposit(requestId: id, note: note);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Approved.")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
      }
    }
  }

  Future<void> _rejectDeposit(BuildContext context, WidgetRef ref, String id) async {
    final reason = await _promptNote(context, title: "Reject deposit", hint: "Reason");
    if (reason == null || reason.isEmpty) return;
    try {
      await ref.read(walletLedgerFunctionsProvider).rejectDeposit(requestId: id, reason: reason);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rejected.")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
      }
    }
  }
}

class _WithdrawalQueueTab extends ConsumerWidget {
  const _WithdrawalQueueTab();

  static String _ts(dynamic v) {
    if (v is Timestamp) {
      return DateFormat.yMMMd().add_jm().format(v.toDate());
    }
    return "—";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(adminPendingWithdrawalsStreamProvider);
    final approved = ref.watch(adminApprovedWithdrawalsStreamProvider);
    final closed = ref.watch(adminClosedWithdrawalsStreamProvider);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text("Pending", style: Theme.of(context).textTheme.titleMedium),
        pending.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text("$e"),
          data: (snap) {
            if (snap.docs.isEmpty) {
              return const Text("None.");
            }
            return Column(
              children: snap.docs.map((doc) {
                final m = doc.data();
                final uid = (m["userId"] ?? "").toString();
                final amt = (m["amount"] as num?)?.toDouble() ?? 0;
                return Card(
                  child: ListTile(
                    title: Text(_money.format(amt)),
                    subtitle: Text("User: $uid · ${_ts(m["createdAt"])}"),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: () => _approveW(context, ref, doc.id),
                          child: const Text("Approve"),
                        ),
                        TextButton(
                          onPressed: () => _rejectW(context, ref, doc.id),
                          child: const Text("Reject"),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        Text("Approved (settle)", style: Theme.of(context).textTheme.titleMedium),
        approved.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text("$e"),
          data: (snap) {
            if (snap.docs.isEmpty) {
              return const Text("None awaiting settlement.");
            }
            return Column(
              children: snap.docs.map((doc) {
                final m = doc.data();
                final uid = (m["userId"] ?? "").toString();
                final amt = (m["amount"] as num?)?.toDouble() ?? 0;
                return Card(
                  child: ListTile(
                    title: Text(_money.format(amt)),
                    subtitle: Text("User: $uid · ${_ts(m["createdAt"])}"),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: () => _completeW(context, ref, doc.id),
                          child: const Text("Complete"),
                        ),
                        TextButton(
                          onPressed: () => _rejectW(context, ref, doc.id),
                          child: const Text("Cancel"),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        Text("Closed", style: Theme.of(context).textTheme.titleMedium),
        closed.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text("$e"),
          data: (snap) {
            if (snap.docs.isEmpty) {
              return const Text("No closed withdrawals.");
            }
            return Column(
              children: snap.docs.map((doc) {
                final m = doc.data();
                final uid = (m["userId"] ?? "").toString();
                final amt = (m["amount"] as num?)?.toDouble() ?? 0;
                final status = (m["status"] ?? "").toString();
                return Card(
                  child: ListTile(
                    title: Text(_money.format(amt)),
                    subtitle: Text("User: $uid · $status · ${_ts(m["updatedAt"])}"),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _approveW(BuildContext context, WidgetRef ref, String id) async {
    final note = await _promptNote(context, title: "Approve withdrawal", hint: "Optional note");
    if (note == null) return;
    try {
      await ref.read(walletLedgerFunctionsProvider).approveWithdrawal(requestId: id, note: note);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Approved.")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
      }
    }
  }

  Future<void> _rejectW(BuildContext context, WidgetRef ref, String id) async {
    final reason = await _promptNote(context, title: "Reject / cancel withdrawal", hint: "Reason");
    if (reason == null || reason.isEmpty) return;
    try {
      await ref.read(walletLedgerFunctionsProvider).rejectWithdrawal(requestId: id, reason: reason);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Updated.")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
      }
    }
  }

  Future<void> _completeW(BuildContext context, WidgetRef ref, String id) async {
    final settlement = await _promptNote(
      context,
      title: "Complete withdrawal",
      hint: "Settlement reference",
    );
    if (settlement == null) return;
    try {
      await ref
          .read(walletLedgerFunctionsProvider)
          .completeWithdrawal(requestId: id, settlementRef: settlement);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Completed.")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
      }
    }
  }
}

class _LedgerTab extends ConsumerWidget {
  const _LedgerTab();

  static String _ts(dynamic v) {
    if (v is Timestamp) {
      return DateFormat.yMMMd().add_jm().format(v.toDate());
    }
    return "—";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminRecentTransactionsStreamProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("$e")),
      data: (snap) {
        if (snap.docs.isEmpty) {
          return const Center(child: Text("No transactions."));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snap.docs.length,
          itemBuilder: (context, i) {
            final doc = snap.docs[i];
            final m = doc.data();
            final type = (m["type"] ?? "").toString();
            final status = (m["status"] ?? "").toString();
            final amt = (m["amount"] as num?)?.toDouble() ?? 0;
            final uid = (m["userId"] ?? "").toString();
            return Card(
              child: ListTile(
                title: Text("$type · ${_money.format(amt)}"),
                subtitle: Text(
                  "$uid\n$status · ${doc.id}\n${_ts(m["createdAt"])}",
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

class _ManualPostingsTab extends ConsumerStatefulWidget {
  const _ManualPostingsTab();

  @override
  ConsumerState<_ManualPostingsTab> createState() => _ManualPostingsTabState();
}

class _AuditTab extends ConsumerWidget {
  const _AuditTab();

  static String _ts(dynamic v) {
    if (v is Timestamp) return DateFormat.yMMMd().add_jm().format(v.toDate());
    return "—";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audit = ref.watch(adminAuditLogsStreamProvider);
    return audit.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("$e")),
      data: (snap) {
        if (snap.docs.isEmpty) return const Center(child: Text("No audit logs."));
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snap.docs.length,
          itemBuilder: (context, i) {
            final m = snap.docs[i].data();
            final action = (m["action"] ?? "").toString();
            final actorRole = (m["actorRole"] ?? "").toString();
            final actorId = (m["actorId"] ?? "").toString();
            final entityType = (m["entityType"] ?? "").toString();
            final entityId = (m["entityId"] ?? "").toString();
            return Card(
              child: ListTile(
                title: Text("$action · $entityType"),
                subtitle: Text("$actorRole:$actorId\n$entityId · ${_ts(m["createdAt"])}"),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

class _ManualPostingsTabState extends ConsumerState<_ManualPostingsTab> {
  final _userId = TextEditingController();
  final _profitAmount = TextEditingController();
  final _profitNote = TextEditingController();
  final _adjAmount = TextEditingController();
  final _adjNote = TextEditingController();
  final _repairUid = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _userId.dispose();
    _profitAmount.dispose();
    _profitNote.dispose();
    _adjAmount.dispose();
    _adjNote.dispose();
    _repairUid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("Profit entry", style: Theme.of(context).textTheme.titleMedium),
        TextField(
          controller: _userId,
          decoration: const InputDecoration(
            labelText: "User ID",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _profitAmount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: "Amount",
            border: OutlineInputBorder(),
          ),
        ),
        TextField(
          controller: _profitNote,
          decoration: const InputDecoration(
            labelText: "Note (optional)",
            border: OutlineInputBorder(),
          ),
        ),
        FilledButton(
          onPressed: _busy ? null : _postProfit,
          child: const Text("Post profit"),
        ),
        const Divider(height: 32),
        Text("Adjustment (signed)", style: Theme.of(context).textTheme.titleMedium),
        TextField(
          controller: _adjAmount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))],
          decoration: const InputDecoration(
            labelText: "Amount (+ / -)",
            border: OutlineInputBorder(),
          ),
        ),
        TextField(
          controller: _adjNote,
          decoration: const InputDecoration(
            labelText: "Justification (required, min 3 chars)",
            border: OutlineInputBorder(),
          ),
        ),
        FilledButton(
          onPressed: _busy ? null : _postAdj,
          child: const Text("Post adjustment"),
        ),
        const Divider(height: 32),
        Text("Repair projection", style: Theme.of(context).textTheme.titleMedium),
        TextField(
          controller: _repairUid,
          decoration: const InputDecoration(
            labelText: "User ID to recalculate",
            border: OutlineInputBorder(),
          ),
        ),
        OutlinedButton(
          onPressed: _busy ? null : _repair,
          child: const Text("Recalculate wallet"),
        ),
      ],
    );
  }

  Future<void> _postProfit() async {
    final uid = _userId.text.trim();
    final amt = double.tryParse(_profitAmount.text.trim());
    if (uid.isEmpty || amt == null || amt <= 0) {
      _toast("Valid user id and amount required.");
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(walletLedgerFunctionsProvider).addProfitEntry(
            userId: uid,
            amount: amt,
            note: _profitNote.text.trim().isEmpty ? null : _profitNote.text.trim(),
          );
      _toast("Profit posted.");
    } catch (e) {
      _toast("$e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _postAdj() async {
    final uid = _userId.text.trim();
    final amt = double.tryParse(_adjAmount.text.trim());
    final note = _adjNote.text.trim();
    if (uid.isEmpty || amt == null || amt == 0 || note.length < 3) {
      _toast("User id, non-zero amount, and note (3+ chars) required.");
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(walletLedgerFunctionsProvider).addAdjustmentEntry(
            userId: uid,
            amount: amt,
            note: note,
          );
      _toast("Adjustment posted.");
    } catch (e) {
      _toast("$e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _repair() async {
    final uid = _repairUid.text.trim();
    if (uid.isEmpty) {
      _toast("User id required.");
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(walletLedgerFunctionsProvider).recalculateWalletForUser(uid);
      _toast("Recalculated.");
    } catch (e) {
      _toast("$e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }
}

Future<String?> _promptNote(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(hintText: hint),
        autofocus: true,
        maxLines: 3,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text("OK"),
        ),
      ],
    ),
  );
  return result;
}
