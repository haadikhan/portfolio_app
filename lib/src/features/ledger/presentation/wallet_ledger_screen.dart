import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../../core/widgets/app_scaffold.dart";
import "../../../providers/wallet_providers.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);

class WalletLedgerScreen extends ConsumerWidget {
  const WalletLedgerScreen({super.key});

  static String _ts(dynamic v) {
    if (v is Timestamp) {
      return DateFormat.yMMMd().add_jm().format(v.toDate());
    }
    return "—";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(userWalletStreamProvider);
    final txsAsync = ref.watch(userTransactionsStreamProvider);

    return AppScaffold(
      title: "Wallet & Ledger",
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
              error: (e, _) => Text("Wallet error: $e"),
              data: (w) {
                if (w == null) {
                  return const Card(
                    child: ListTile(
                      title: Text("No wallet data yet"),
                      subtitle: Text(
                        "Submit a deposit after KYC approval, or wait for sync.",
                      ),
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
                        title: const Text("Current balance"),
                        subtitle: Text(
                          _money.format(current),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        title: const Text("Available"),
                        subtitle: Text(_money.format(avail)),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        title: const Text("Reserved (withdrawals)"),
                        subtitle: Text(_money.format(reserved)),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        title: const Text("Totals"),
                        subtitle: Text(
                          "Deposited: ${_money.format(td)}\n"
                          "Withdrawn: ${_money.format(tw)}\n"
                          "Profit: ${_money.format(tp)}\n"
                          "Adjustments: ${_money.format(ta)}",
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
                    child: const Text("Deposit request"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => context.push("/wallet-ledger/withdraw"),
                    child: const Text("Withdrawal"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              "Transaction history",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            txsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text("History error: $e"),
              data: (snap) {
                if (snap == null || snap.docs.isEmpty) {
                  return const Text("No transactions yet.");
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
                          "${d.id}\n$status · ${_ts(m["createdAt"])}",
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
