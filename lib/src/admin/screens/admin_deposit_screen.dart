import "package:cloud_firestore/cloud_firestore.dart";
import "package:cloud_functions/cloud_functions.dart";
import "package:file_picker/file_picker.dart";
import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../providers/auth_providers.dart";

/// Admin-only: credit an investor's wallet directly via the
/// `adminInitiateDeposit` callable — bypasses the investor deposit-request
/// flow entirely. The deposit (and optional front-end load fee) are written
/// to the same `transactions` collection the investor app already reads,
/// so they appear in the investor's wallet ledger and reports automatically.
class AdminDepositScreen extends ConsumerStatefulWidget {
  const AdminDepositScreen({
    super.key,
    required this.userId,
    required this.investorName,
  });

  final String userId;
  final String investorName;

  @override
  ConsumerState<AdminDepositScreen> createState() =>
      _AdminDepositScreenState();
}

class _AdminDepositScreenState extends ConsumerState<AdminDepositScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  bool _applyFrontEndFee = true;
  bool _isSubmitting = false;
  bool _isUploadingProof = false;
  String? _proofImageUrl;

  static final _money =
      NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);

  double get _enteredAmount => double.tryParse(_amountController.text) ?? 0;

  double get _feeAmount => _applyFrontEndFee
      ? double.parse((_enteredAmount * 0.02).toStringAsFixed(2))
      : 0;

  double get _netAmount =>
      double.parse((_enteredAmount - _feeAmount).toStringAsFixed(2));

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() => setState(() {});

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadProof() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;

    setState(() => _isUploadingProof = true);
    try {
      final path = "deposit_proofs/${widget.userId}/"
          "${DateTime.now().millisecondsSinceEpoch}.jpg";
      final ref = FirebaseStorage.instance.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: "image/jpeg"));
      final url = await ref.getDownloadURL();
      if (!mounted) return;
      setState(() => _proofImageUrl = url);
    } catch (e) {
      // Proof is optional — a failed upload must never block the deposit.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Proof upload failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _isUploadingProof = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Confirm Deposit"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Investor: ${widget.investorName}"),
            Text("Amount: ${_money.format(_enteredAmount)}"),
            if (_applyFrontEndFee) ...[
              Text(
                "Fee (2%): -${_money.format(_feeAmount)}",
                style: const TextStyle(color: Colors.red),
              ),
              Text(
                "Net Credit: ${_money.format(_netAmount)}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ] else
              Text(
                "Net Credit: ${_money.format(_enteredAmount)}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 8),
            const Text(
              "This will immediately credit the investor's wallet. "
              "This action cannot be undone.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: "us-central1")
          .httpsCallable("adminInitiateDeposit");
      await callable.call(<String, dynamic>{
        "userId": widget.userId,
        "amountPkr": _enteredAmount,
        "applyFrontEndFee": _applyFrontEndFee,
        if (_proofImageUrl != null) "proofImageUrl": _proofImageUrl,
        "notes": _notesController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Deposit of ${_money.format(_enteredAmount)} credited "
            "successfully"
            "${_applyFrontEndFee ? " (net ${_money.format(_netAmount)} after 2% fee)" : ""}",
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e, st) {
      debugPrint("[admin_deposit] failed: $e\n$st");
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text("Deposit Error (debug)"),
            content: SingleChildScrollView(
              child: SelectableText("$e\n\n$st"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Close"),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Make Deposit")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InvestorInfoCard(
                userId: widget.userId,
                investorName: widget.investorName,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r"^\d+\.?\d{0,2}"),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: "Deposit Amount (PKR)",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final amt = double.tryParse(v ?? "");
                      if (amt == null || amt <= 0) {
                        return "Enter a valid amount";
                      }
                      if (amt < 1000) {
                        return "Minimum deposit is PKR 1,000";
                      }
                      return null;
                    },
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
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Apply Front-End Load Fee",
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  "2% deducted from deposit amount",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _applyFrontEndFee,
                            onChanged: (v) =>
                                setState(() => _applyFrontEndFee = v),
                          ),
                        ],
                      ),
                      if (_amountController.text.isNotEmpty &&
                          _applyFrontEndFee) ...[
                        const Divider(),
                        _FeePreviewRow(
                          "Gross Amount",
                          _money.format(_enteredAmount),
                        ),
                        _FeePreviewRow(
                          "Front-End Fee (2%)",
                          "-${_money.format(_feeAmount)}",
                          isRed: true,
                        ),
                        _FeePreviewRow(
                          "Net Credited Amount",
                          _money.format(_netAmount),
                          isBold: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Payment Proof (Optional)",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      if (_proofImageUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            _proofImageUrl!,
                            height: 140,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed:
                              _isUploadingProof ? null : _pickAndUploadProof,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Change"),
                        ),
                      ] else
                        OutlinedButton.icon(
                          onPressed:
                              _isUploadingProof ? null : _pickAndUploadProof,
                          icon: _isUploadingProof
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_outlined),
                          label: Text(
                            _isUploadingProof
                                ? "Uploading…"
                                : "Upload Proof Image",
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Notes (Optional)",
                      hintText:
                          "e.g. Cash deposit at office, reference number, etc.",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Confirm Deposit"),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvestorInfoCard extends ConsumerWidget {
  const _InvestorInfoCard({
    required this.userId,
    required this.investorName,
  });

  final String userId;
  final String investorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: ref
              .read(firebaseFirestoreProvider)
              .collection("users")
              .doc(userId)
              .snapshots(),
          builder: (context, snap) {
            final portfolioNumber =
                (snap.data?.data()?["portfolioNumber"] as String?) ?? "—";
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  investorName.isEmpty ? "Investor" : investorName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text("Portfolio #: $portfolioNumber"),
                const SizedBox(height: 4),
                SelectableText(
                  "UID: $userId",
                  style:
                      const TextStyle(fontFamily: "monospace", fontSize: 12),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FeePreviewRow extends StatelessWidget {
  const _FeePreviewRow(
    this.label,
    this.value, {
    this.isRed = false,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isRed;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isRed ? Colors.red : null,
            ),
          ),
        ],
      ),
    );
  }
}
