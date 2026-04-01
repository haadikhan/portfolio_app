import "dart:io";

import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:image_picker/image_picker.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../providers/auth_providers.dart";
import "../../../providers/wallet_providers.dart";

const _paymentMethods = [
  ("bank_transfer", "Bank Transfer"),
  ("easypaisa", "EasyPaisa"),
  ("jazzcash", "JazzCash"),
  ("raast", "Raast"),
  ("other", "Other"),
];

class DepositRequestScreen extends ConsumerStatefulWidget {
  const DepositRequestScreen({super.key});

  @override
  ConsumerState<DepositRequestScreen> createState() =>
      _DepositRequestScreenState();
}

class _DepositRequestScreenState extends ConsumerState<DepositRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String _selectedMethod = "bank_transfer";
  File? _proofFile;
  bool _busy = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (x != null) setState(() => _proofFile = File(x.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    setState(() => _busy = true);
    try {
      // Upload proof if one was picked — use the already-picked file, never re-open gallery
      String? proofUrl;
      if (_proofFile != null) {
        final path =
            "deposit_proofs/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg";
        final storageRef = FirebaseStorage.instance.ref(path);
        await storageRef.putFile(_proofFile!);
        proofUrl = await storageRef.getDownloadURL();
      }

      final amount = double.parse(_amountController.text.trim());
      await ref.read(walletLedgerFunctionsProvider).createDepositRequest(
            amount: amount,
            paymentMethod: _selectedMethod,
            proofUrl: proofUrl,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Deposit request submitted. Awaiting admin approval."),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains("not-found") || raw.contains("NOT_FOUND")) {
      return "Service temporarily unavailable. Please try again later.";
    }
    if (raw.contains("KYC must be approved")) {
      return "Your KYC must be approved before making a deposit.";
    }
    if (raw.contains("unauthenticated")) {
      return "Session expired. Please log in again.";
    }
    return raw.replaceAll("Exception: ", "");
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Request deposit",
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Transfer funds to our account, then submit this form with your payment proof. An admin will verify and credit your balance.",
                        style: TextStyle(
                            fontSize: 12, color: Colors.blue.shade800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Amount
              _SectionLabel(label: "Amount"),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Amount (PKR)",
                  prefixIcon: Icon(Icons.attach_money_rounded),
                  hintText: "e.g. 50000",
                ),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? "");
                  if (n == null || n <= 0) return "Enter a valid amount";
                  if (n < 100) return "Minimum deposit is PKR 100";
                  return null;
                },
              ),

              // Payment method
              const SizedBox(height: 20),
              _SectionLabel(label: "Payment method"),
              const SizedBox(height: 8),
              ...(_paymentMethods.map((m) => _MethodTile(
                    value: m.$1,
                    label: m.$2,
                    selected: _selectedMethod == m.$1,
                    onTap: () => setState(() => _selectedMethod = m.$1),
                  ))),

              // Proof image
              const SizedBox(height: 20),
              _SectionLabel(label: "Payment proof"),
              const SizedBox(height: 4),
              const Text(
                "Attach a screenshot of your transfer receipt (recommended).",
                style: TextStyle(fontSize: 12, color: AppColors.bodyMuted),
              ),
              const SizedBox(height: 10),
              _ProofPicker(
                file: _proofFile,
                busy: _busy,
                onPick: _pickProof,
                onRemove: () => setState(() => _proofFile = null),
              ),

              // Submit
              const SizedBox(height: 28),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _busy ? "Submitting…" : "Submit deposit request",
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.bodyMuted,
        letterSpacing: 0.4,
      ),
    );
  }
}

// ─── Payment method tile ──────────────────────────────────────────────────────

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.value,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String value;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.secondary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppColors.primary : AppColors.bodyMuted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.heading : AppColors.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Proof image picker ───────────────────────────────────────────────────────

class _ProofPicker extends StatelessWidget {
  const _ProofPicker({
    required this.file,
    required this.busy,
    required this.onPick,
    required this.onRemove,
  });
  final File? file;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (file != null) {
      // Show preview with remove option — tapping does NOT re-open gallery
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              file!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          if (!busy)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text("Proof attached",
                      style:
                          TextStyle(color: Colors.white, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // No file yet — show pick button
    return GestureDetector(
      onTap: busy ? null : onPick,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.border, style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: AppColors.primary, size: 30),
            SizedBox(height: 6),
            Text(
              "Tap to attach proof (optional)",
              style:
                  TextStyle(fontSize: 12, color: AppColors.bodyMuted),
            ),
          ],
        ),
      ),
    );
  }
}
