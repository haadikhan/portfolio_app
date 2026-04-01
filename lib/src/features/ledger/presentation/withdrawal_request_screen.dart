import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

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
        const SnackBar(content: Text("Enter a valid amount.")),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(walletLedgerFunctionsProvider).createWithdrawalRequest(amount: amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Withdrawal request submitted.")),
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
      title: "Request withdrawal",
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          walletAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text("Wallet: $e"),
            data: (w) {
              final avail = (w?["availableBalance"] as num?)?.toDouble() ?? 0;
              final res = (w?["reservedAmount"] as num?)?.toDouble() ?? 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Available: ${avail.toStringAsFixed(2)} PKR"),
                  Text("Reserved: ${res.toStringAsFixed(2)} PKR"),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            "Funds are reserved while your request is pending. An admin will approve and mark settlement when paid out.",
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: "Amount (PKR)",
              border: OutlineInputBorder(),
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
                : const Text("Submit request"),
          ),
        ],
      ),
    );
  }
}
