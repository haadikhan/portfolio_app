import "package:cloud_functions/cloud_functions.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_error_dialog.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../providers/mpin_providers.dart";
import "../../../providers/wallet_providers.dart";
import "../../investment/data/allocation_money_market.dart";
import "../../mpin/presentation/mpin_prompt_dialog.dart";

class WithdrawalRequestScreen extends ConsumerStatefulWidget {
  const WithdrawalRequestScreen({super.key});

  @override
  ConsumerState<WithdrawalRequestScreen> createState() =>
      _WithdrawalRequestScreenState();
}

class _WithdrawalRequestScreenState extends ConsumerState<WithdrawalRequestScreen> {
  final _amountController = TextEditingController();
  bool _busy = false;
  String? _inlineError;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  bool _isInsufficientBalanceMessage(String? message) {
    if (message == null || message.isEmpty) return false;
    final m = message.toLowerCase();
    return m.contains("insufficient") && m.contains("balance");
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, "0");
    final m = t.minute.toString().padLeft(2, "0");
    return "$h:$m";
  }

  void _showFailure(String message) {
    setState(() => _inlineError = message);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
    showAppErrorMessageDialog(context, message);
  }

  Future<void> _submit() async {
    setState(() => _inlineError = null);
    final parsed = double.tryParse(_amountController.text.trim());
    if (parsed == null || parsed <= 0) {
      _showFailure(context.tr("enter_valid_amount"));
      return;
    }

    final amount = double.parse(parsed.toStringAsFixed(2));

    final walletState = ref.read(userWalletStreamProvider);
    if (walletState.isLoading) {
      _showFailure(context.tr("wallet_balance_still_loading"));
      return;
    }
    if (walletState.hasError) {
      _showFailure(context.tr("wallet_balance_unavailable"));
      return;
    }

    final w = walletState.value;
    final moneyMarketWithdrawable = double.parse(
      moneyMarketAvailableFromWallet(w).toStringAsFixed(2),
    );
    debugPrint(
      "[withdraw] submit amount=$amount mmAvailable=$moneyMarketWithdrawable "
      "wallet.mmCredited=${w?["moneyMarketCreditedTotal"]} "
      "wallet.mmWithdrawn=${w?["moneyMarketWithdrawnTotal"]} "
      "wallet.mmReserved=${w?["moneyMarketReserved"]} "
      "wallet.totalDeposited=${w?["totalDeposited"]} "
      "wallet.totalWithdrawn=${w?["totalWithdrawn"]} "
      "wallet.reservedAmount=${w?["reservedAmount"]}",
    );
    if (amount > moneyMarketWithdrawable) {
      _showFailure(context.tr("withdrawal_exceeds_money_market"));
      return;
    }

    // MPIN gate: prompt the user when their MPIN is configured AND enabled.
    // No prompt for users who never set one (full backward-compat).
    String? mpin;
    final mpinStatus = ref.read(mpinStatusStreamProvider).value;
    if (mpinStatus != null && mpinStatus.hasMpin && mpinStatus.enabled) {
      if (mpinStatus.isLockedNow) {
        _showFailure(
          context.trParams("mpin_locked", {
            "time": _formatTime(mpinStatus.lockedUntil!),
          }),
        );
        return;
      }
      mpin = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const MpinPromptDialog(),
      );
      if (!mounted) return;
      if (mpin == null) return; // user cancelled
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(walletLedgerFunctionsProvider)
          .createWithdrawalRequest(amount: amount, mpin: mpin);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr("withdrawal_submitted")),
          backgroundColor: Colors.green.shade700,
        ),
      );
      context.pop();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      debugPrint("[withdraw] FirebaseFunctionsException code=${e.code} message=${e.message}");
      final raw = e.message?.trim() ?? "";
      String text;
      if (raw == "MPIN_WRONG") {
        text = context.tr("mpin_wrong");
      } else if (raw == "MPIN_LOCKED") {
        // Lockout was just applied by server; the stream will refresh shortly,
        // but we surface a friendly message immediately.
        text = context.tr("mpin_locked_short");
      } else if (raw == "MPIN_INVALID_FORMAT") {
        text = context.tr("mpin_invalid_format");
      } else if (_isInsufficientBalanceMessage(e.message)) {
        text = context.tr("withdrawal_exceeds_money_market");
      } else {
        text = e.message?.trim().isNotEmpty == true
            ? "${e.message!} (${e.code})"
            : e.code;
      }
      _showFailure(text);
    } catch (e) {
      if (!mounted) return;
      debugPrint("[withdraw] unexpected error: $e");
      setState(() => _inlineError = e.toString());
      await showAppErrorDialog(context, e);
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
              final mm = moneyMarketAvailableFromWallet(w);
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
                  Text(
                    context.trParams("withdrawable_money_market_pkrf", {
                      "amount": mm.toStringAsFixed(2),
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
          if (_inlineError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _inlineError!,
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
