import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../providers/wallet_providers.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);

class WalletLedgerScreen extends ConsumerWidget {
  const WalletLedgerScreen({super.key});

  static String _ts(BuildContext context, dynamic v) {
    if (v is Timestamp) {
      return DateFormat.yMMMd().add_jm().format(v.toDate());
    }
    return context.tr("em_dash");
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(userWalletStreamProvider);
    final txsAsync = ref.watch(userTransactionsStreamProvider);

    return AppScaffold(
      title: context.tr("wallet_ledger_title"),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userWalletStreamProvider);
          ref.invalidate(userTransactionsStreamProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            walletAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text("${context.tr("wallet_error")} $e"),
              data: (w) {
                if (w == null) {
                  return Card(
                    child: ListTile(
                      title: Text(context.tr("no_wallet_data")),
                      subtitle: Text(context.tr("no_wallet_subtitle")),
                    ),
                  );
                }
                final current = (w["currentBalance"] as num?)?.toDouble() ?? 0;
                final avail = (w["availableBalance"] as num?)?.toDouble() ?? 0;
                final reserved = (w["reservedAmount"] as num?)?.toDouble() ?? 0;
                final td = (w["totalDeposited"] as num?)?.toDouble() ?? 0;
                final tw = (w["totalWithdrawn"] as num?)?.toDouble() ?? 0;
                final tp = (w["totalProfit"] as num?)?.toDouble() ?? 0;
                final ta = (w["totalAdjustments"] as num?)?.toDouble() ?? 0;
                return Column(
                  children: [
                    Card(
                      child: ListTile(
                        title: Text(context.tr("current_balance")),
                        subtitle: Text(
                          _money.format(current),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        title: Text(context.tr("available")),
                        subtitle: Text(_money.format(avail)),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        title: Text(context.tr("reserved_withdrawals")),
                        subtitle: Text(_money.format(reserved)),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        title: Text(context.tr("totals")),
                        subtitle: Text(
                          "${context.tr("totals_line_deposited")} ${_money.format(td)}\n"
                          "${context.tr("totals_line_withdrawn")} ${_money.format(tw)}\n"
                          "${context.tr("totals_line_profit")} ${_money.format(tp)}\n"
                          "${context.tr("totals_line_adjustments")} ${_money.format(ta)}",
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => context.push("/wallet-ledger/deposit"),
                    child: Text(context.tr("deposit_request")),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => context.push("/wallet-ledger/withdraw"),
                    child: Text(context.tr("withdrawal_request_btn")),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              context.tr("transaction_history"),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            txsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text("${context.tr("history_error")} $e"),
              data: (snap) {
                if (snap == null || snap.docs.isEmpty) {
                  return Text(context.tr("no_transactions_yet"));
                }
                return Column(
                  children: snap.docs.map((d) {
                    final m = d.data();
                    final type = (m["type"] ?? "").toString();
                    final status = (m["status"] ?? "").toString();
                    final amt = (m["amount"] as num?)?.toDouble() ?? 0;
                    return Card(
                      child: ListTile(
                        title: Text(
                          "${type.toUpperCase()} · ${_money.format(amt)}",
                        ),
                        subtitle: Text(
                          "${d.id}\n$status · ${_ts(context, m["createdAt"])}",
                        ),
                        isThreeLine: true,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
