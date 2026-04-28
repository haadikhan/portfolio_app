import "package:cloud_functions/cloud_functions.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

/// Returns & profit entry screen embedded in the admin panel sidebar.
/// All writes go through the [applyMonthlyReturns] Cloud Function so that
/// the Admin SDK bypasses Firestore security rules and transactions are
/// written atomically server-side.
class AdminReturnsScreen extends ConsumerStatefulWidget {
  const AdminReturnsScreen({super.key});

  @override
  ConsumerState<AdminReturnsScreen> createState() => _AdminReturnsScreenState();
}

class _AdminReturnsScreenState extends ConsumerState<AdminReturnsScreen> {
  final _pctController = TextEditingController();
  final _globalAnnualRateController = TextEditingController();
  bool _processing = false;
  bool _savingProjectionConfig = false;
  bool _repairingWithdrawals = false;
  bool _recalcingWallets = false;

  final _fn = FirebaseFunctions.instanceFor(region: "us-central1");
  final _db = FirebaseFirestore.instance;

  @override
  void dispose() {
    _pctController.dispose();
    _globalAnnualRateController.dispose();
    super.dispose();
  }

  Future<void> _saveProjectionConfig() async {
    final rate = double.tryParse(_globalAnnualRateController.text.trim());
    if (rate == null || rate < 0 || rate > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter a valid annual projection rate (0–100)."),
        ),
      );
      return;
    }
    setState(() => _savingProjectionConfig = true);
    try {
      await _fn.httpsCallable("saveReturnsProjectionConfig").call({
        "globalAnnualRatePct": rate,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Live projection configuration saved.")),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        "internal" || "not-found" || "unavailable" =>
          "Server config is not updated yet. Deploy/restart Cloud Functions and try again.",
        _ => e.message ?? e.code,
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save projection settings: $message"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save projection settings: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingProjectionConfig = false);
    }
  }

  Future<void> _apply() async {
    final pct = double.tryParse(_pctController.text.trim());
    if (pct == null || pct <= 0 || pct > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter a valid return percentage (0–100)."),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm return application"),
        content: Text(
          "Apply $pct% monthly return to all active portfolios?\n\n"
          "This will update portfolio balances and write to the "
          "transaction ledger.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Confirm & apply"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);
    try {
      final result = await _fn.httpsCallable("applyMonthlyReturns").call({
        "returnPct": pct,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;

      final currency = NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);
      final successCount = data["successCount"] as int? ?? 0;
      final failCount = data["failCount"] as int? ?? 0;
      final totalProfit = (data["totalProfit"] as num?)?.toDouble() ?? 0.0;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
              SizedBox(width: 8),
              Text("Return applied"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Successful: $successCount user(s)"),
              if (failCount > 0)
                Text(
                  "Failed: $failCount user(s)",
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 4),
              Text(
                "Total profit distributed: "
                "${currency.format(totalProfit)}",
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Done"),
            ),
          ],
        ),
      );
      _pctController.clear();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.message ?? e.code}"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _repairWithdrawals() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Repair legacy approved withdrawals"),
        content: const Text(
          "This settles any withdrawal that is still in 'approved' status (no "
          "explicit completion record) by transitioning it to 'completed' and "
          "recalculating the affected investor wallets.\n\n"
          "Run this once after the canonical withdrawal contract change. Safe "
          "to re-run — already-settled records are skipped.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Run repair"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _repairingWithdrawals = true);
    try {
      final result = await _fn
          .httpsCallable("repairApprovedWithdrawals")
          .call({"dryRun": false});
      if (!mounted) return;
      final data = Map<String, dynamic>.from(result.data as Map);
      final updated = data["updated"] as int? ?? 0;
      final scanned = data["scanned"] as int? ?? 0;
      final users = (data["affectedUsers"] as List?)?.length ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Repair done — scanned $scanned, updated $updated, "
            "users affected: $users.",
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Repair failed: ${e.message ?? e.code}"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Repair failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _repairingWithdrawals = false);
    }
  }

  Future<void> _recalcAllWallets() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Recalculate all wallets"),
        content: const Text(
          "Recomputes every investor wallet from their transaction ledger and "
          "writes back canonical fields including the new money-market bucket "
          "fields (moneyMarketCreditedTotal / moneyMarketAvailable). Safe to "
          "re-run.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Recalculate"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _recalcingWallets = true);
    try {
      final result =
          await _fn.httpsCallable("repairUserBalances").call(<String, dynamic>{});
      if (!mounted) return;
      final data = Map<String, dynamic>.from(result.data as Map);
      final fixed = data["fixedCount"] as int? ?? 0;
      final total = data["totalUsers"] as int? ?? 0;
      final errors = data["errorCount"] as int? ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Recalculated $total wallets. Adjusted: $fixed. Errors: $errors.",
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Recalc failed: ${e.message ?? e.code}"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Recalc failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _recalcingWallets = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Returns & profit entry",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            "Apply monthly returns to all investor portfolios.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Percentage return — all users",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Applies the entered % to the current value of every "
                    "portfolio. Runs server-side — safe and atomic.",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: _pctController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "Monthly return %",
                        hintText: "e.g. 5.0",
                        prefixIcon: Icon(Icons.percent_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _processing ? null : _apply,
                    icon: _processing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _processing ? "Processing…" : "Apply to all users",
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _db
                .collection("settings")
                .doc("returns_projection")
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              final currentRate =
                  (data?["globalAnnualRatePct"] as num?)?.toDouble() ?? 0.0;
              if (_globalAnnualRateController.text.isEmpty) {
                _globalAnnualRateController.text = currentRate.toStringAsFixed(
                  2,
                );
              }
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Live projected profit rate",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Set annual projected rate used for live investor "
                        "profit preview. This does not write ledger entries.",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 320,
                        child: TextField(
                          controller: _globalAnnualRateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: "Annual projection %",
                            hintText: "e.g. 25",
                            prefixIcon: Icon(Icons.timeline_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: _savingProjectionConfig
                              ? null
                              : _saveProjectionConfig,
                          icon: _savingProjectionConfig
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined, size: 18),
                          label: Text(
                            _savingProjectionConfig
                                ? "Saving…"
                                : "Save projection settings",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue.shade100),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "For per-user manual profit entry, use the Apply "
                      "Returns console in the main admin app.",
                      style: TextStyle(fontSize: 13, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.orange.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.build_circle_outlined,
                        color: Colors.orange.shade800,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Wallet maintenance",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "One-time repair tools to align legacy data with the "
                    "current wallet & money-market projection contract.",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _repairingWithdrawals
                            ? null
                            : _repairWithdrawals,
                        icon: _repairingWithdrawals
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.history_rounded, size: 18),
                        label: Text(
                          _repairingWithdrawals
                              ? "Repairing…"
                              : "Repair legacy approved withdrawals",
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _recalcingWallets ? null : _recalcAllWallets,
                        icon: _recalcingWallets
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.calculate_outlined, size: 18),
                        label: Text(
                          _recalcingWallets
                              ? "Recalculating…"
                              : "Recalculate all wallets",
                        ),
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
