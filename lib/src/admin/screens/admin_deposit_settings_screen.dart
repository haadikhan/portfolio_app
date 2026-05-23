import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../services/deposit_settings_service.dart";

/// Admin screen to edit company bank details shown on investor deposit (bank transfer).
class AdminDepositSettingsScreen extends ConsumerStatefulWidget {
  const AdminDepositSettingsScreen({super.key});

  @override
  ConsumerState<AdminDepositSettingsScreen> createState() =>
      _AdminDepositSettingsScreenState();
}

class _AdminDepositSettingsScreenState
    extends ConsumerState<AdminDepositSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();

  final _service = DepositSettingsService();

  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _bankNameCtrl,
      _accountHolderCtrl,
      _ibanCtrl,
      _branchCtrl,
      _instructionsCtrl,
    ]) {
      c.addListener(_onFieldsChanged);
    }
    _loadExisting();
  }

  void _onFieldsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _accountHolderCtrl.dispose();
    _ibanCtrl.dispose();
    _branchCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final data = await _service.loadDepositInstructions();
      if (data != null && mounted) {
        _bankNameCtrl.text = data["companyBankName"] as String? ?? "";
        _accountHolderCtrl.text = data["accountHolderName"] as String? ?? "";
        _ibanCtrl.text = data["ibanOrAccountNumber"] as String? ?? "";
        _branchCtrl.text = data["branchName"] as String? ?? "";
        _instructionsCtrl.text = data["instructions"] as String? ?? "";
      }
    } catch (_) {
      // Screen remains usable if load fails.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canSave =>
      !_saving &&
      !_loading &&
      _bankNameCtrl.text.trim().isNotEmpty &&
      _accountHolderCtrl.text.trim().isNotEmpty &&
      _ibanCtrl.text.trim().length >= 10;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _service.saveDepositInstructions(
        companyBankName: _bankNameCtrl.text,
        accountHolderName: _accountHolderCtrl.text,
        ibanOrAccountNumber: _ibanCtrl.text,
        branchName: _branchCtrl.text,
        instructions: _instructionsCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bank details saved successfully"),
            backgroundColor: Color(0xFF0F7A2C),
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message ?? "Failed to save. Please try again.",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save. Please try again. ($e)")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Deposit Bank Settings",
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Manage company bank account shown to investors during deposit",
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
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
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "These details are shown to investors when they select "
                      "Bank Transfer as payment method. Keep this information "
                      "accurate and up to date.",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? scheme.onSurface
                            : Colors.blue.shade800,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              "Required Information",
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _bankNameCtrl,
              decoration: const InputDecoration(
                labelText: "Bank Name",
                hintText: "e.g. HBL, UBL, Meezan Bank",
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return "Bank name is required";
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountHolderCtrl,
              decoration: const InputDecoration(
                labelText: "Account Holder Name",
                hintText: "Full name as registered with bank",
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return "Account holder name is required";
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ibanCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: "IBAN or Account Number",
                hintText: "e.g. PK36SCBL0000001123456702",
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final t = v?.trim() ?? "";
                if (t.isEmpty) return "IBAN or account number is required";
                if (t.length < 10) {
                  return "Enter at least 10 characters";
                }
                return null;
              },
            ),
            const SizedBox(height: 28),
            Text(
              "Optional Information",
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _branchCtrl,
              decoration: const InputDecoration(
                labelText: "Branch Name (optional)",
                hintText: "e.g. Main Boulevard, Karachi",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _instructionsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Additional Instructions (optional)",
                hintText: "Any special instructions for depositors",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              "Preview (investor view)",
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            _InvestorBankPreviewCard(
              bankName: _bankNameCtrl.text.trim(),
              accountHolderName: _accountHolderCtrl.text.trim(),
              iban: _ibanCtrl.text.trim(),
              branchName: _branchCtrl.text.trim(),
              instructions: _instructionsCtrl.text.trim(),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Save Bank Details",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mirrors investor [_BankDetailsCard] styling for live admin preview.
class _InvestorBankPreviewCard extends StatelessWidget {
  const _InvestorBankPreviewCard({
    required this.bankName,
    required this.accountHolderName,
    required this.iban,
    required this.branchName,
    required this.instructions,
  });

  final String bankName;
  final String accountHolderName;
  final String iban;
  final String branchName;
  final String instructions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayBank = bankName.isEmpty ? "—" : bankName;
    final displayHolder = accountHolderName.isEmpty ? "—" : accountHolderName;
    final displayIban = iban.isEmpty ? "—" : iban;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_rounded,
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                "Transfer to",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _previewRow(context, label: "Bank", value: displayBank),
          _previewRow(context, label: "Account name", value: displayHolder),
          _previewRow(
            context,
            label: "Account / IBAN",
            value: displayIban,
            trailing: iban.isNotEmpty
                ? Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: scheme.primary,
                  )
                : null,
          ),
          if (branchName.isNotEmpty)
            _previewRow(context, label: "Branch", value: branchName),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              instructions,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _previewRow(
    BuildContext context, {
    required String label,
    required String value,
    Widget? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
