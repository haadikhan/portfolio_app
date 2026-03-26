import "package:collection/collection.dart";

import "../models/domain_models.dart";

class LedgerService {
  const LedgerService();

  WalletSnapshot deriveWallet(Iterable<LedgerTransaction> transactions) {
    final approved = transactions.where(
      (t) =>
          t.status == TransactionStatus.approved ||
          t.status == TransactionStatus.completed,
    );

    final totalDeposited = approved
        .where((t) => t.type == TransactionType.deposit)
        .map((t) => t.amount)
        .sum;
    final totalWithdrawn = approved
        .where((t) => t.type == TransactionType.withdrawal)
        .map((t) => t.amount)
        .sum;
    final totalProfit = approved
        .where((t) => t.type == TransactionType.profit)
        .map((t) => t.amount)
        .sum;
    final reserved = transactions
        .where(
          (t) =>
              t.type == TransactionType.withdrawal &&
              t.status == TransactionStatus.pending,
        )
        .map((t) => t.amount)
        .sum;

    return WalletSnapshot(
      totalDeposited: totalDeposited,
      totalWithdrawn: totalWithdrawn,
      totalProfit: totalProfit,
      reservedAmount: reserved,
    );
  }

  List<LedgerTransaction> applyMonthlyReturn({
    required List<LedgerTransaction> existing,
    required double percentage,
    required DateTime cycleDate,
  }) {
    final monthKey = "${cycleDate.year}-${cycleDate.month}";
    final alreadyPosted = existing.any(
      (t) =>
          t.type == TransactionType.profit &&
          (t.notes ?? "").contains("return-cycle:$monthKey"),
    );
    if (alreadyPosted) return existing;

    final wallet = deriveWallet(existing);
    final profitAmount = wallet.currentBalance * (percentage / 100);
    final profitTx = LedgerTransaction(
      id: "PROFIT-$monthKey",
      userId: "all",
      type: TransactionType.profit,
      status: TransactionStatus.approved,
      amount: profitAmount,
      createdAt: cycleDate,
      notes: "return-cycle:$monthKey",
    );
    return [...existing, profitTx];
  }
}
