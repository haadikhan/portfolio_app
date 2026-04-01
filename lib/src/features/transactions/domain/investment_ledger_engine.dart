import "../../../core/common/value_enums.dart";
import "../../wallet/domain/wallet_entity.dart";
import "ledger_book.dart";
import "transaction_entity.dart";

class InvestmentLedgerEngine {
  const InvestmentLedgerEngine();

  TransactionEntity requestDeposit({
    required String txId,
    required String userId,
    required double amount,
    String? notes,
  }) {
    return TransactionEntity(
      id: txId,
      userId: userId,
      type: TransactionType.deposit,
      amount: amount,
      status: TransactionStatus.pending,
      createdAt: DateTime.now(),
      notes: notes,
    );
  }

  TransactionEntity approveDeposit(TransactionEntity pendingDeposit) {
    _assertType(pendingDeposit, TransactionType.deposit);
    _assertPending(pendingDeposit);
    return pendingDeposit.copyWith(status: TransactionStatus.approved);
  }

  TransactionEntity requestWithdrawal({
    required String txId,
    required String userId,
    required double amount,
    required WalletEntity wallet,
    required double reservedAmount,
    String? notes,
  }) {
    if ((wallet.balance - reservedAmount) < amount) {
      throw StateError("Insufficient available balance for withdrawal request.");
    }
    return TransactionEntity(
      id: txId,
      userId: userId,
      type: TransactionType.withdrawal,
      amount: amount,
      status: TransactionStatus.pending,
      createdAt: DateTime.now(),
      notes: notes,
    );
  }

  TransactionEntity approveWithdrawal(TransactionEntity pendingWithdrawal) {
    _assertType(pendingWithdrawal, TransactionType.withdrawal);
    _assertPending(pendingWithdrawal);
    return pendingWithdrawal.copyWith(status: TransactionStatus.approved);
  }

  TransactionEntity completeWithdrawal(TransactionEntity approvedWithdrawal) {
    _assertType(approvedWithdrawal, TransactionType.withdrawal);
    if (approvedWithdrawal.status != TransactionStatus.approved) {
      throw StateError("Only approved withdrawals can be completed.");
    }
    return approvedWithdrawal.copyWith(status: TransactionStatus.completed);
  }

  TransactionEntity createProfitTransaction({
    required String txId,
    required String userId,
    required double percentage,
    required WalletEntity wallet,
    String? notes,
  }) {
    final profit = wallet.balance * (percentage / 100);
    return TransactionEntity(
      id: txId,
      userId: userId,
      type: TransactionType.profit,
      amount: profit,
      status: TransactionStatus.approved,
      createdAt: DateTime.now(),
      notes:
          "${notes ?? ""} Indicative/Admin-entered/Not guaranteed".trim(),
    );
  }

  WalletEntity calculateWallet({
    required String userId,
    required LedgerBook ledger,
  }) {
    double deposits = 0;
    double withdrawals = 0;
    double profits = 0;

    for (final tx in ledger.transactions.where((t) => t.userId == userId)) {
      final isCountable = tx.status == TransactionStatus.approved ||
          tx.status == TransactionStatus.completed;
      if (!isCountable) continue;

      switch (tx.type) {
        case TransactionType.deposit:
          deposits += tx.amount;
          break;
        case TransactionType.withdrawal:
          withdrawals += tx.amount;
          break;
        case TransactionType.profit:
          profits += tx.amount;
          break;
        case TransactionType.adjustment:
          profits += tx.amount;
          break;
      }
    }

    return WalletEntity(
      userId: userId,
      totalDeposited: deposits,
      totalWithdrawn: withdrawals,
      totalProfit: profits,
    );
  }

  void _assertType(TransactionEntity tx, TransactionType expected) {
    if (tx.type != expected) {
      throw StateError("Invalid transaction type for this operation.");
    }
  }

  void _assertPending(TransactionEntity tx) {
    if (tx.status != TransactionStatus.pending) {
      throw StateError("Only pending transactions can be approved.");
    }
  }
}
