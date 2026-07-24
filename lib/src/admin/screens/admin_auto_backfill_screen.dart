import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../providers/wallet_providers.dart";
import "../providers/admin_providers.dart";

class AdminAutoBackfillScreen extends ConsumerStatefulWidget {
  const AdminAutoBackfillScreen({super.key});

  @override
  ConsumerState<AdminAutoBackfillScreen> createState() =>
      _AdminAutoBackfillScreenState();
}

class _AdminAutoBackfillScreenState
    extends ConsumerState<AdminAutoBackfillScreen> {
  final _userIdCtl = TextEditingController();
  // Each deposit entry: { controller: TextEditingController, date: DateTime? }
  final List<_DepositEntry> _deposits = [_DepositEntry()];
  bool _busy = false;
  bool _previewDone = false;
  Map<String, dynamic>? _previewResult;

  static final _money =
      NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);

  @override
  void dispose() {
    _userIdCtl.dispose();
    for (final d in _deposits) {
      d.dispose();
    }
    super.dispose();
  }

  bool _inputsValid() {
    if (_userIdCtl.text.trim().isEmpty) return false;
    if (_deposits.isEmpty) return false;
    for (final d in _deposits) {
      final amt = double.tryParse(d.amountCtl.text.trim());
      if (amt == null || amt <= 0 || d.date == null) return false;
    }
    return true;
  }

  Future<void> _runPreview() async {
    if (!_inputsValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Enter user ID and at least one deposit with amount and date.",
          ),
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _previewResult = null;
      _previewDone = false;
    });
    try {
      final depositsPayload = _deposits
          .map((d) => <String, dynamic>{
                "date": "${d.date!.year.toString().padLeft(4, '0')}"
                    "-${d.date!.month.toString().padLeft(2, '0')}"
                    "-${d.date!.day.toString().padLeft(2, '0')}",
                "amount": double.parse(d.amountCtl.text.trim()),
              })
          .toList();

      final result = await ref
          .read(walletLedgerFunctionsProvider)
          .adminAutoBackfillInvestor(
            userId: _userIdCtl.text.trim(),
            deposits: depositsPayload,
            dryRun: true,
          );
      if (mounted) {
        setState(() {
          _previewResult = result;
          _previewDone = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Preview failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runBackfill() async {
    if (!_inputsValid() || !_previewDone) return;

    final uid = _userIdCtl.text.trim();
    final months =
        (_previewResult?["monthsProcessed"] as num?)?.toInt() ?? 0;
    final net =
        (_previewResult?["totalNetProfit"] as num?)?.toDouble() ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text("Confirm auto-backfill"),
        content: Text(
          "This will write $months month(s) of historical entries "
          "for investor $uid.\n\n"
          "Total net profit: ${_money.format(net)}\n\n"
          "All backdated transactions, return history, and fee "
          "statements will be created. This cannot be undone "
          "automatically.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text("Run backfill"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final depositsPayload = _deposits
          .map((d) => <String, dynamic>{
                "date": "${d.date!.year.toString().padLeft(4, '0')}"
                    "-${d.date!.month.toString().padLeft(2, '0')}"
                    "-${d.date!.day.toString().padLeft(2, '0')}",
                "amount": double.parse(d.amountCtl.text.trim()),
              })
          .toList();

      final result = await ref
          .read(walletLedgerFunctionsProvider)
          .adminAutoBackfillInvestor(
            userId: uid,
            deposits: depositsPayload,
            dryRun: false,
          );

      if (mounted) {
        final processedMonths = result["monthsProcessed"] ?? 0;
        final totalNet =
            (result["totalNetProfit"] as num?)?.toDouble() ?? 0;
        final missing =
            (result["missingEodDays"] as num?)?.toInt() ?? 0;

        _userIdCtl.clear();
        setState(() {
          for (final d in _deposits) {
            d.amountCtl.clear();
            d.date = null;
          }
          // Keep one empty entry
          if (_deposits.length > 1) {
            for (final d in _deposits.skip(1)) {
              d.dispose();
            }
            _deposits.removeRange(1, _deposits.length);
          }
          _previewDone = false;
          _previewResult = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Backfill complete — $processedMonths months, "
              "${_money.format(totalNet)} net profit credited."
              "${missing > 0 ? " ($missing days had no market data — fixed rates used.)" : ""}",
            ),
            duration: const Duration(seconds: 7),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Backfill failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(adminRoleProvider).valueOrNull ?? "";
    final isAdmin = role.toLowerCase() == "admin";
    final scheme = Theme.of(context).colorScheme;

    if (!isAdmin) {
      return const Scaffold(
        body: Center(child: Text("Access restricted to admin role.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Auto Backfill")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_fix_high_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Automated Backdated Entry",
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Enter a deposit date and amount. The system reads "
                          "historical PSX + Gold EOD data and automatically "
                          "generates all transactions, return history, and "
                          "fee statements.",
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Investor details",
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _userIdCtl,
                        onChanged: (_) => setState(() {
                          _previewDone = false;
                          _previewResult = null;
                        }),
                        decoration: const InputDecoration(
                          labelText: "User ID",
                          hintText: "Firebase UID of the investor",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Deposits",
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (int i = 0; i < _deposits.length; i++) ...[
                        _DepositRowWidget(
                          index: i + 1,
                          entry: _deposits[i],
                          canRemove: _deposits.length > 1,
                          onDatePick: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _deposits[i].date ??
                                  DateTime.now().subtract(
                                      const Duration(days: 30)),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now()
                                  .subtract(const Duration(days: 1)),
                            );
                            if (picked != null) {
                              setState(() {
                                _deposits[i].date = picked;
                                _previewDone = false;
                                _previewResult = null;
                              });
                            }
                          },
                          onRemove: () => setState(() {
                            _deposits[i].dispose();
                            _deposits.removeAt(i);
                            _previewDone = false;
                            _previewResult = null;
                          }),
                          onChanged: (_) => setState(() {
                            _previewDone = false;
                            _previewResult = null;
                          }),
                        ),
                        const SizedBox(height: 8),
                      ],
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _deposits.add(_DepositEntry());
                          _previewDone = false;
                          _previewResult = null;
                        }),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("Add another deposit"),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_previewResult != null) ...[
                _PreviewResultCard(
                  result: _previewResult!,
                  money: _money,
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _runPreview,
                      icon: _busy && !_previewDone
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.preview_rounded),
                      label: const Text("Preview calculation"),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          (_busy || !_previewDone) ? null : _runBackfill,
                      icon: _busy && _previewDone
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.rocket_launch_rounded),
                      label: const Text("Run backfill"),
                      style: FilledButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _previewDone
                    ? "Preview looks correct? Tap Run backfill to write all entries."
                    : "Run Preview first to verify the calculation before writing.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Card(
                elevation: 0,
                color: scheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "How it works",
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      for (final item in [
                        (
                          "1",
                          "Reads all PSX KMI30 + Gold EOD data already stored "
                              "in Firestore from the deposit date to yesterday.",
                        ),
                        (
                          "2",
                          "Applies stock/gold % day by day. Fixed annual rates "
                              "used for tech, debt, and money market.",
                        ),
                        (
                          "3",
                          "Aggregates profit month by month. Each month's net "
                              "profit compounds into the base for next month.",
                        ),
                        (
                          "4",
                          "Writes: one deposit transaction + one profit entry, "
                              "return history row, and fee statement per month.",
                        ),
                        (
                          "5",
                          "If EOD data is missing for a day, stock/gold = 0% "
                              "for that day. Fixed rates still apply.",
                        ),
                      ]) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  item.$1,
                                  style: TextStyle(
                                    color: scheme.onPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.$2,
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewResultCard extends StatelessWidget {
  const _PreviewResultCard({required this.result, required this.money});

  final Map<String, dynamic> result;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final months = (result["months"] as List?)?.cast<Map>() ?? [];
    final totalGross =
        (result["totalGrossProfit"] as num?)?.toDouble() ?? 0;
    final totalNet =
        (result["totalNetProfit"] as num?)?.toDouble() ?? 0;
    final totalFees =
        (result["totalFees"] as num?)?.toDouble() ?? 0;
    final missing =
        (result["missingEodDays"] as num?)?.toInt() ?? 0;

    return Card(
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: scheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  "Preview — ${months.length} month(s)",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    "Month",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Days",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    "Net profit",
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 12),
            for (final m in months) ...[
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      m["monthKey"]?.toString() ?? "",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "${m["tradingDays"] ?? 0} days",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      money.format(
                        (m["netProfit"] as num?)?.toDouble() ?? 0,
                      ),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            const Divider(height: 12),
            _Row(
              label: "Gross profit",
              value: money.format(totalGross),
              scheme: scheme,
            ),
            if (totalFees > 0) ...[
              const SizedBox(height: 4),
              _Row(
                label: "Performance fees",
                value: "- ${money.format(totalFees)}",
                scheme: scheme,
                valueColor: scheme.error,
              ),
            ],
            const SizedBox(height: 4),
            _Row(
              label: "Net profit to investor",
              value: money.format(totalNet),
              scheme: scheme,
              bold: true,
            ),
            if (missing > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Colors.amber.shade800,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "$missing trading day(s) had no EOD snapshot. "
                        "Stock and gold = 0% for those days. "
                        "Fixed rates (tech/debt/money) still applied.",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.scheme,
    this.bold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final ColorScheme scheme;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  bold ? FontWeight.w700 : FontWeight.w400,
              color: bold
                  ? scheme.onSurface
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                bold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ??
                (bold ? scheme.onSurface : null),
          ),
        ),
      ],
    );
  }
}

class _DepositEntry {
  final TextEditingController amountCtl = TextEditingController();
  DateTime? date;

  void dispose() => amountCtl.dispose();
}

class _DepositRowWidget extends StatelessWidget {
  const _DepositRowWidget({
    required this.index,
    required this.entry,
    required this.canRemove,
    required this.onDatePick,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final _DepositEntry entry;
  final bool canRemove;
  final VoidCallback onDatePick;
  final VoidCallback onRemove;
  final ValueChanged<String> onChanged;

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')} "
      "${const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month]} "
      "${d.year}";

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                "Deposit $index",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (canRemove)
                GestureDetector(
                  onTap: onRemove,
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: scheme.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: entry.amountCtl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: "Amount (PKR)",
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onDatePick,
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(
              entry.date == null
                  ? "Pick deposit date"
                  : _fmtDate(entry.date!),
              style: const TextStyle(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          if (entry.date != null) ...[
            const SizedBox(height: 6),
            Text(
              "⚠ Backdated to ${_fmtDate(entry.date!)}",
              style: TextStyle(
                fontSize: 11,
                color: Colors.amber.shade800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
