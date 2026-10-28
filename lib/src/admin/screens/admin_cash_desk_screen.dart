import "package:cloud_functions/cloud_functions.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../debug/agent_debug_log.dart";
import "../../core/formatting/grouped_decimal_input.dart";
import "../cash_desk/cash_desk_logic.dart";
import "../models/admin_investor_models.dart";
import "../providers/admin_cash_desk_providers.dart";
import "../providers/admin_providers.dart";
import "../services/admin_cash_desk_service.dart";

class AdminCashDeskScreen extends ConsumerStatefulWidget {
  const AdminCashDeskScreen({super.key, this.initialUserId});

  final String? initialUserId;

  @override
  ConsumerState<AdminCashDeskScreen> createState() =>
      _AdminCashDeskScreenState();
}

class _AdminCashDeskScreenState extends ConsumerState<AdminCashDeskScreen> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();
  final _search = TextEditingController();
  String? _userId;
  bool _busy = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialUserId?.trim();
    _userId = (initial == null || initial.isEmpty) ? null : initial;
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    _search.dispose();
    super.dispose();
  }

  double _num(Map<String, dynamic>? wallet, String key) {
    final v = wallet?[key];
    if (v is num && v.isFinite) return v.toDouble();
    return 0;
  }

  Future<void> _submit({
    required bool credit,
    required double available,
    required String investorName,
    required String portfolioNumber,
  }) async {
    setState(() {
      _error = null;
      _success = null;
    });
    final parsed = parseGroupedDecimal(_amount.text);
    final amountError = CashDeskFormLogic.validateAmount(
      amount: parsed,
      available: available,
    );
    if (!credit && amountError != null) {
      setState(() => _error = amountError);
      return;
    }
    if (credit && (parsed == null || !parsed.isFinite || parsed <= 0)) {
      setState(() => _error = "Enter an amount greater than zero.");
      return;
    }
    final amount = double.parse(parsed!.toStringAsFixed(2));
    final before = double.parse(available.toStringAsFixed(2));
    final after = CashDeskFormLogic.balanceAfter(
      available: before,
      amount: amount,
      credit: credit,
    );
    final actionLabel = credit ? "Cash Credit" : "Cash Withdrawal (Debit)";
    final key = CashDeskFormLogic.newIdempotencyKey();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(actionLabel),
        content: Text(
          "Investor: $investorName\n"
          "Portfolio: ${portfolioNumber.isEmpty ? "—" : portfolioNumber}\n"
          "Action: $actionLabel\n"
          "Amount: PKR ${amount.toStringAsFixed(2)}\n"
          "Balance before: PKR ${before.toStringAsFixed(2)}\n"
          "Balance after: PKR ${after.toStringAsFixed(2)}",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final caller = ref.read(adminCashDeskServiceProvider);
      final CashDeskResult result;
      if (credit) {
        result = await caller.credit(
          userId: _userId!,
          amount: amount,
          reference: _reference.text,
          note: _note.text,
          idempotencyKey: key,
        );
      } else {
        result = await caller.withdraw(
          userId: _userId!,
          amount: amount,
          reference: _reference.text,
          note: _note.text,
          idempotencyKey: key,
        );
      }
      if (!mounted) return;
      setState(() {
        _success =
            "$actionLabel posted. Balance after PKR ${result.balanceAfter.toStringAsFixed(2)}.";
        _amount.clear();
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      // #region agent log
      agentDebugLog(
        location: "admin_cash_desk_screen.dart:_submit",
        message: "callable failed",
        hypothesisId: "H1-H2",
        data: {
          "code": e.code,
          "message": e.message ?? "",
          "details": e.details?.toString() ?? "",
        },
      );
      // #endregion
      setState(() => _error = _cashDeskCallableErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      // #region agent log
      agentDebugLog(
        location: "admin_cash_desk_screen.dart:_submit",
        message: "callable threw",
        hypothesisId: "H1",
        data: {"error": e.toString()},
      );
      // #endregion
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final investorsAsync = ref.watch(filteredInvestorsProvider);
    final recentAsync = ref.watch(cashDeskRecentProvider);
    final uid = _userId;
    final walletAsync = uid == null ? null : ref.watch(cashDeskWalletProvider(uid));
    final blockersAsync =
        uid == null ? null : ref.watch(cashDeskBlockersProvider(uid));
    final portfolioAsync =
        uid == null ? null : ref.watch(cashDeskPortfolioNumberProvider(uid));

    final investors = investorsAsync.valueOrNull ?? const <AdminInvestorSummary>[];
    AdminInvestorSummary? selected;
    for (final u in investors) {
      if (u.userId == uid) selected = u;
    }
    final investorName = selected == null
        ? (uid ?? "")
        : (selected.name.isNotEmpty ? selected.name : selected.userId);

    final wallet = walletAsync?.valueOrNull;
    final walletReady = uid != null && walletAsync?.hasValue == true && wallet != null;
    final available = _num(wallet, "availableBalance");
    if (uid != null && walletReady) {
      // #region agent log
      agentDebugLog(
        location: "admin_cash_desk_screen.dart:build",
        message: "cash desk wallet breakdown",
        hypothesisId: "H3",
        data: {
          "userId": uid,
          "availableBalance": available,
          "totalDeposited": _num(wallet, "totalDeposited"),
          "totalProfit": _num(wallet, "totalProfit"),
          "totalFees": _num(wallet, "totalFees"),
          "totalWithdrawn": _num(wallet, "totalWithdrawn"),
        },
      );
      // #endregion
    }
    final blockers = blockersAsync?.valueOrNull ?? const <CashDeskBlocker>[];
    final blocked = blockers.isNotEmpty;
    final portfolioNumber = portfolioAsync?.valueOrNull ?? "";
    final canAct = CashDeskFormLogic.actionsEnabled(
      busy: _busy,
      blocked: blocked,
      hasInvestor: uid != null,
      walletReady: walletReady,
    );

    return Stack(
      children: [
        Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Text("Cash Desk", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            "Record a cash withdrawal or a cash credit for one investor. "
            "Both post immediately.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              labelText: "Search investor",
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) =>
                ref.read(investorSearchQueryProvider.notifier).state = v,
          ),
          const SizedBox(height: 8),
          if (uid == null)
            const Text("Select an investor.")
          else
            Text("Selected: $investorName"),
          const SizedBox(height: 8),
          investorsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text("Could not load investors: $e"),
            data: (items) {
              if (items.isEmpty) return const Text("No investors match.");
              return Column(
                children: [
                  for (final u in items.take(20))
                    ListTile(
                      dense: true,
                      selected: u.userId == uid,
                      title: Text(u.name.isNotEmpty ? u.name : u.userId),
                      subtitle: Text(u.email.isEmpty ? u.userId : u.email),
                      onTap: _busy
                          ? null
                          : () => setState(() {
                                _userId = u.userId;
                                _error = null;
                                _success = null;
                              }),
                    ),
                ],
              );
            },
          ),
          if (uid != null) ...[
            const SizedBox(height: 16),
            if (walletAsync == null || walletAsync.isLoading)
              const LinearProgressIndicator()
            else if (walletAsync.hasError)
              Text("Could not load wallet: ${walletAsync.error}")
            else if (wallet == null)
              const Text("No wallet document yet.")
            else
              _BalanceCard(wallet: wallet, read: _num),
            const SizedBox(height: 8),
            const Text(
              "Today's profit not yet credited is excluded. "
              "Payout is based on the ledger balance at this moment.",
            ),
            if (blocked) ...[
              const SizedBox(height: 12),
              Text(
                CashDeskFormLogic.blockedMessage(blockers),
                key: const Key("cash_desk_blocked"),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              Text(
                "Cash Desk cannot post until every open deposit or withdrawal "
                "request is approved or rejected in the admin queues.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => context.go("/deposits"),
                    child: const Text("Open Deposits queue"),
                  ),
                  TextButton(
                    onPressed:
                        _busy ? null : () => context.go("/withdrawals"),
                    child: const Text("Open Withdrawals queue"),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              key: const Key("cash_desk_amount"),
              controller: _amount,
              enabled: !_busy,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [GroupedDecimalInputFormatter()],
              decoration: const InputDecoration(
                labelText: "Amount (PKR)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: (!walletReady || _busy)
                    ? null
                    : () => _amount.text =
                        CashDeskFormLogic.fullBalanceText(available),
                child: const Text("Withdraw full balance"),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reference,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: "Reference / receipt (optional)",
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: "Note (optional)"),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: canAct
                      ? () => _submit(
                            credit: false,
                            available: available,
                            investorName: investorName,
                            portfolioNumber: portfolioNumber,
                          )
                      : null,
                  child: const Text("Cash Withdrawal (Debit)"),
                ),
                FilledButton(
                  onPressed: canAct
                      ? () => _submit(
                            credit: true,
                            available: available,
                            investorName: investorName,
                            portfolioNumber: portfolioNumber,
                          )
                      : null,
                  child: const Text("Cash Credit"),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const Key("cash_desk_error"),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_success != null) ...[
            const SizedBox(height: 12),
            Text(_success!, key: const Key("cash_desk_success")),
          ],
          const SizedBox(height: 28),
          Text("Recent cash desk entries",
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          recentAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text("Could not load recent entries: $e"),
            data: (rows) {
              if (rows.isEmpty) return const Text("No cash desk entries yet.");
              final dt = DateFormat.yMMMd().add_Hm();
              return Column(
                children: [
                  for (final row in rows)
                    ListTile(
                      dense: true,
                      title: Text(
                        "${_entryLabel(row.type)} · PKR ${row.amount.toStringAsFixed(2)}",
                      ),
                      subtitle: Text(
                        "${row.userId} · ${row.adminUid}"
                        "${row.createdAt == null ? "" : " · ${dt.format(row.createdAt!.toLocal())}"}",
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
        if (_busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x44000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  String _entryLabel(String type) {
    switch (type.toLowerCase()) {
      case "withdrawal":
        return "Cash Debit (Admin)";
      case "deposit":
        return "Cash Credit (Admin)";
      default:
        return type;
    }
  }
}

String _cashDeskCallableErrorMessage(FirebaseFunctionsException e) {
  final code = e.code.toLowerCase();
  final msg = (e.message ?? "").trim();
  if (code == "not-found") {
    return "Could not reach adminCashWithdraw/adminCashCredit on Firebase. "
        "Deploy those Cloud Functions, then retry.";
  }
  if (code == "failed-precondition" && msg.isNotEmpty) return msg;
  if (msg.isNotEmpty && msg.toLowerCase() != "internal") return "$code: $msg";
  if (code == "internal") {
    return "The server returned an internal error. Refresh this page — if "
        "available balance already changed, the cash desk entry was saved.";
  }
  return code;
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet, required this.read});

  final Map<String, dynamic> wallet;
  final double Function(Map<String, dynamic>?, String) read;

  @override
  Widget build(BuildContext context) {
    String line(String label, String key) =>
        "$label: PKR ${read(wallet, key).toStringAsFixed(2)}";
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Ledger balance",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(line("Total deposited", "totalDeposited")),
            Text(line("Total profit", "totalProfit")),
            Text(line("Total adjustments", "totalAdjustments")),
            Text(line("Total fees", "totalFees")),
            Text(line("Total withdrawn", "totalWithdrawn")),
            Text(line("Reserved", "reservedAmount")),
            Text(line("Available balance", "availableBalance")),
          ],
        ),
      ),
    );
  }
}
