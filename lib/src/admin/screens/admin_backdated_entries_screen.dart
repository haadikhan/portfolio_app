import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../providers/wallet_providers.dart";
import "../providers/admin_providers.dart";

class AdminBackdatedEntriesScreen extends ConsumerStatefulWidget {
  const AdminBackdatedEntriesScreen({super.key});

  @override
  ConsumerState<AdminBackdatedEntriesScreen> createState() =>
      _AdminBackdatedEntriesScreenState();
}

class _AdminBackdatedEntriesScreenState
    extends ConsumerState<AdminBackdatedEntriesScreen> {
  final _profitUserId = TextEditingController();
  final _profitAmount = TextEditingController();
  final _profitNote = TextEditingController();
  DateTime? _profitDate;
  bool _profitBusy = false;

  final _adjUserId = TextEditingController();
  final _adjAmount = TextEditingController();
  final _adjNote = TextEditingController();
  DateTime? _adjDate;
  bool _adjBusy = false;

  final _depUserId = TextEditingController();
  final _depAmount = TextEditingController();
  final _depNote = TextEditingController();
  String _depMethod = "admin_entry";
  DateTime? _depDate;
  bool _depositBusy = false;

  @override
  void dispose() {
    _profitUserId.dispose();
    _profitAmount.dispose();
    _profitNote.dispose();
    _adjUserId.dispose();
    _adjAmount.dispose();
    _adjNote.dispose();
    _depUserId.dispose();
    _depAmount.dispose();
    _depNote.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime? current,
    required void Function(DateTime?) onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) onPicked(picked);
  }

  Widget _dateRow({
    required DateTime? selected,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return Row(
      children: [
        const Icon(Icons.calendar_today_outlined, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            selected == null
                ? "Date: Today (current)"
                : "Date: ${selected.day.toString().padLeft(2, '0')} "
                    "${_monthName(selected.month)} ${selected.year}",
            style: const TextStyle(fontSize: 13),
          ),
        ),
        TextButton(onPressed: onTap, child: const Text("Change")),
        if (selected != null)
          TextButton(
            onPressed: onClear,
            child: const Text("Reset to today"),
          ),
      ],
    );
  }

  String _monthName(int m) => const [
        "",
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ][m];

  Widget _backdatedWarning(DateTime? date) {
    if (date == null) return const SizedBox.shrink();
    final isBackdated = !(date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day);
    if (!isBackdated) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Colors.amber.shade800,
          ),
          const SizedBox(width: 6),
          Text(
            "Backdated entry — will appear in past records",
            style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
          ),
        ],
      ),
    );
  }

  Future<void> _postProfit() async {
    final uid = _profitUserId.text.trim();
    final amt = double.tryParse(_profitAmount.text.trim());
    if (uid.isEmpty || amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Valid user id and amount required.")),
      );
      return;
    }
    setState(() => _profitBusy = true);
    try {
      await ref.read(walletLedgerFunctionsProvider).addProfitEntryWithDate(
            userId: uid,
            amount: amt,
            note: _profitNote.text.trim().isEmpty
                ? null
                : _profitNote.text.trim(),
            effectiveDate: _profitDate,
          );
      _profitUserId.clear();
      _profitAmount.clear();
      _profitNote.clear();
      setState(() => _profitDate = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Profit entry posted for $uid")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _profitBusy = false);
    }
  }

  Future<void> _postAdj() async {
    final uid = _adjUserId.text.trim();
    final amt = double.tryParse(_adjAmount.text.trim());
    final note = _adjNote.text.trim();
    if (uid.isEmpty || amt == null || amt == 0 || note.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "User id, non-zero amount, and note (3+ chars) required.",
          ),
        ),
      );
      return;
    }
    setState(() => _adjBusy = true);
    try {
      await ref.read(walletLedgerFunctionsProvider).addAdjustmentEntryWithDate(
            userId: uid,
            amount: amt,
            note: note,
            effectiveDate: _adjDate,
          );
      _adjUserId.clear();
      _adjAmount.clear();
      _adjNote.clear();
      setState(() => _adjDate = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Adjustment posted for $uid")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _adjBusy = false);
    }
  }

  Future<void> _postDeposit() async {
    final uid = _depUserId.text.trim();
    final amtStr = _depAmount.text.trim();
    if (uid.isEmpty || amtStr.isEmpty) return;
    final amt = double.tryParse(amtStr);
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid positive amount.")),
      );
      return;
    }
    setState(() => _depositBusy = true);
    try {
      await ref.read(walletLedgerFunctionsProvider).adminCreateDeposit(
            userId: uid,
            amount: amt,
            note: _depNote.text.trim().isEmpty ? null : _depNote.text.trim(),
            paymentMethod: _depMethod,
            effectiveDate: _depDate,
          );
      _depUserId.clear();
      _depAmount.clear();
      _depNote.clear();
      setState(() {
        _depMethod = "admin_entry";
        _depDate = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Deposit posted for $uid")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _depositBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(adminRoleProvider).valueOrNull ?? "";
    final isAdmin = role.toLowerCase() == "admin";

    return Scaffold(
      appBar: AppBar(title: const Text("Backdated Entries")),
      body: isAdmin
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Post historical entries for investors. "
                    "All entries are logged for audit.",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Backdated profit entry",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _profitUserId,
                            decoration: const InputDecoration(
                              labelText: "User ID",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _profitAmount,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: "Amount",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _profitNote,
                            decoration: const InputDecoration(
                              labelText: "Note (optional)",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _dateRow(
                            selected: _profitDate,
                            onTap: () => _pickDate(
                              current: _profitDate,
                              onPicked: (d) =>
                                  setState(() => _profitDate = d),
                            ),
                            onClear: () =>
                                setState(() => _profitDate = null),
                          ),
                          _backdatedWarning(_profitDate),
                          FilledButton(
                            onPressed: _profitBusy ? null : _postProfit,
                            child: _profitBusy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text("Post profit entry"),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Backdated adjustment entry",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _adjUserId,
                            decoration: const InputDecoration(
                              labelText: "User ID",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _adjAmount,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^-?\d*\.?\d*'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: "Amount (+ / -)",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _adjNote,
                            decoration: const InputDecoration(
                              labelText:
                                  "Justification (required, min 3 chars)",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _dateRow(
                            selected: _adjDate,
                            onTap: () => _pickDate(
                              current: _adjDate,
                              onPicked: (d) => setState(() => _adjDate = d),
                            ),
                            onClear: () => setState(() => _adjDate = null),
                          ),
                          _backdatedWarning(_adjDate),
                          FilledButton(
                            onPressed: _adjBusy ? null : _postAdj,
                            child: _adjBusy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text("Post adjustment"),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Admin deposit entry",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _depUserId,
                            decoration: const InputDecoration(
                              labelText: "User ID",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _depAmount,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: "Amount (PKR)",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _depMethod,
                            decoration: const InputDecoration(
                              labelText: "Payment method",
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: "admin_entry",
                                child: Text("Admin entry"),
                              ),
                              DropdownMenuItem(
                                value: "bank_transfer",
                                child: Text("Bank transfer"),
                              ),
                              DropdownMenuItem(
                                value: "cheque",
                                child: Text("Cheque"),
                              ),
                              DropdownMenuItem(
                                value: "cash",
                                child: Text("Cash"),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _depMethod = v ?? "admin_entry"),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _depNote,
                            decoration: const InputDecoration(
                              labelText: "Note (optional)",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _dateRow(
                            selected: _depDate,
                            onTap: () => _pickDate(
                              current: _depDate,
                              onPicked: (d) => setState(() => _depDate = d),
                            ),
                            onClear: () => setState(() => _depDate = null),
                          ),
                          _backdatedWarning(_depDate),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _depositBusy ? null : _postDeposit,
                            child: _depositBusy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text("Post deposit"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const Center(
              child: Text("Access restricted to admin role."),
            ),
    );
  }
}
