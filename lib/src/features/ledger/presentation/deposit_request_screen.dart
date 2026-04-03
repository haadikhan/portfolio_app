import "dart:io";

import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:image_picker/image_picker.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../providers/auth_providers.dart";
import "../../../providers/wallet_providers.dart";

const _paymentMethodKeys = <(String, String)>[
  ("bank_transfer", "method_bank_transfer"),
  ("easypaisa", "method_easypaisa"),
  ("jazzcash", "method_jazzcash"),
  ("raast", "method_raast"),
  ("other", "method_other"),
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
        SnackBar(
          content: Text(context.tr("deposit_submitted_snack")),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(context, e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(BuildContext context, String raw) {
    if (raw.contains("not-found") || raw.contains("NOT_FOUND")) {
      return context.tr("err_service_unavailable");
    }
    if (raw.contains("KYC must be approved")) {
      return context.tr("err_kyc_required_deposit");
    }
    if (raw.contains("unauthenticated")) {
      return context.tr("err_session_expired");
    }
    return raw.replaceAll("Exception: ", "");
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      title: context.tr("request_deposit_title"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? scheme.primaryContainer.withValues(alpha: 0.35)
                      : const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? scheme.outline : Colors.blue.shade200,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr("deposit_info_banner"),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? scheme.onSurface
                              : Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionLabel(label: context.tr("amount_label")),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: context.tr("amount_pkr"),
                  prefixIcon: const Icon(Icons.attach_money_rounded),
                  hintText: context.tr("amount_hint_example"),
                ),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? "");
                  if (n == null || n <= 0) return context.tr("err_amount_valid");
                  if (n < 100) return context.tr("err_min_deposit");
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: context.tr("payment_method")),
              const SizedBox(height: 8),
              ...(_paymentMethodKeys.map((m) => _MethodTile(
                    value: m.$1,
                    label: context.tr(m.$2),
                    selected: _selectedMethod == m.$1,
                    onTap: () => setState(() => _selectedMethod = m.$1),
                  ))),
              const SizedBox(height: 20),
              _SectionLabel(label: context.tr("payment_proof")),
              const SizedBox(height: 4),
              Text(
                context.tr("payment_proof_help"),
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              _ProofPicker(
                file: _proofFile,
                busy: _busy,
                onPick: _pickProof,
                onRemove: () => setState(() => _proofFile = null),
              ),
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
                    _busy
                        ? context.tr("submitting")
                        : context.tr("submit_deposit_request_btn"),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: scheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
    );
  }
}

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
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.4)
              : scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    final scheme = Theme.of(context).colorScheme;
    if (file != null) {
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(context.tr("proof_attached"),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: busy ? null : onPick,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: scheme.primary, size: 30),
            const SizedBox(height: 6),
            Text(
              context.tr("tap_attach_proof"),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
