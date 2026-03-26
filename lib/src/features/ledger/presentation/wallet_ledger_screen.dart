import "package:flutter/material.dart";

import "../../../core/models/domain_models.dart";
import "../../../core/services/ledger_service.dart";
import "../../../core/widgets/app_scaffold.dart";

class WalletLedgerScreen extends StatelessWidget {
  const WalletLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final txs = [
      LedgerTransaction(
        id: "TXN-1",
        userId: "U1",
        type: TransactionType.deposit,
        status: TransactionStatus.approved,
        amount: 100000,
        createdAt: DateTime(2026, 1, 1),
      ),
      LedgerTransaction(
        id: "TXN-2",
        userId: "U1",
        type: TransactionType.profit,
        status: TransactionStatus.approved,
        amount: 5000,
        createdAt: DateTime(2026, 2, 1),
      ),
      LedgerTransaction(
        id: "TXN-3",
        userId: "U1",
        type: TransactionType.withdrawal,
        status: TransactionStatus.pending,
        amount: 10000,
        createdAt: DateTime(2026, 2, 3),
      ),
    ];

    final wallet = const LedgerService().deriveWallet(txs);

    return AppScaffold(
      title: "Wallet & Ledger",
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text("Current Balance"),
              subtitle: Text(wallet.currentBalance.toStringAsFixed(2)),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text("Total Deposited"),
              subtitle: Text(wallet.totalDeposited.toStringAsFixed(2)),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text("Reserved for Withdrawals"),
              subtitle: Text(wallet.reservedAmount.toStringAsFixed(2)),
            ),
          ),
          const SizedBox(height: 12),
          const Text("Immutable Ledger"),
          ...txs.map(
            (tx) => ListTile(
              title: Text("${tx.type.name.toUpperCase()} ${tx.amount}"),
              subtitle: Text("${tx.id} • ${tx.status.name}"),
            ),
          ),
        ],
      ),
    );
  }
}
