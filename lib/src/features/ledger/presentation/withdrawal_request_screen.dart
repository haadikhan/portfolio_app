import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../providers/wallet_providers.dart";

class WithdrawalRequestScreen extends ConsumerStatefulWidget {
  const WithdrawalRequestScreen({super.key});

  @override
  ConsumerState<WithdrawalRequestScreen> createState() =>
      _WithdrawalRequestScreenState();
}

class _WithdrawalRequestScreenState extends ConsumerState<WithdrawalRequestScreen> {
  final _amountController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("enter_valid_amount"))),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(walletLedgerFunctionsProvider).createWithdrawalRequest(amount: amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("withdrawal_submitted"))),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(userWalletStreamProvider);

    return AppScaffold(
      title: context.tr("request_withdrawal_title"),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          walletAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text("${context.tr("wallet_prefix")} $e"),
            data: (w) {
              final avail = (w?["availableBalance"] as num?)?.toDouble() ?? 0;
              final res = (w?["reservedAmount"] as num?)?.toDouble() ?? 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.trParams("available_pkrf", {
                      "amount": avail.toStringAsFixed(2),
                    }),
                  ),
                  Text(
                    context.trParams("reserved_pkrf", {
                      "amount": res.toStringAsFixed(2),
                    }),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(context.tr("withdrawal_reserved_note")),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.tr("amount_pkr"),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr("submit_request")),
          ),
        ],
      ),
    );
  }
}
