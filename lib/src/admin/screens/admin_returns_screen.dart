import "package:cloud_functions/cloud_functions.dart";
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
  ConsumerState<AdminReturnsScreen> createState() =>
      _AdminReturnsScreenState();
}

class _AdminReturnsScreenState extends ConsumerState<AdminReturnsScreen> {
  final _pctController = TextEditingController();
  bool _processing = false;

  final _fn = FirebaseFunctions.instanceFor(region: "us-central1");

  @override
  void dispose() {
    _pctController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final pct = double.tryParse(_pctController.text.trim());
    if (pct == null || pct <= 0 || pct > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Enter a valid return percentage (0–100).")),
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
              child: const Text("Cancel")),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Confirm & apply")),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);
    try {
      final result = await _fn
          .httpsCallable("applyMonthlyReturns")
          .call({"returnPct": pct});

      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;

      final currency =
          NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);
      final successCount = data["successCount"] as int? ?? 0;
      final failCount = data["failCount"] as int? ?? 0;
      final totalProfit =
          (data["totalProfit"] as num?)?.toDouble() ?? 0.0;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 22),
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
              Text("Total profit distributed: "
                  "${currency.format(totalProfit)}"),
            ],
          ),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Done")),
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
        SnackBar(
            content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Returns & profit entry",
              style: Theme.of(context).textTheme.headlineSmall),
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
                          decimal: true),
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
                                color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_processing
                        ? "Processing…"
                        : "Apply to all users"),
                  ),
                ],
              ),
            ),
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
                  Icon(Icons.info_outline_rounded,
                      color: Colors.blue, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "For per-user manual profit entry, use the Apply "
                      "Returns console in the main admin app.",
                      style:
                          TextStyle(fontSize: 13, color: Colors.blue),
                    ),
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
