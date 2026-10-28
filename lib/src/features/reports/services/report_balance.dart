import "../../../core/formatting/transaction_display.dart";
import "../../investor/data/models/txn_item.dart";

/// Portfolio ledger balance aligned with [recalculateWallet] in wallet_helpers.js.
bool reportTxnSettled(String status) {
  final st = status.toLowerCase();
  return st == "approved" || st == "completed";
}

/// Applies one settled transaction to a running portfolio balance (PKR).
double applyReportTxnToBalance(TxnItem t, double balance) {
  if (!reportTxnSettled(t.status)) return balance;

  final ty = t.type.toLowerCase();
  final amt = t.amount.abs();

  if (ty == "deposit") {
    return balance + amt;
  }
  if (ty == "withdrawal") {
    final st = t.status.toLowerCase();
    if (st == "completed" ||
        st == "approved" ||
        st == "pending") {
      return balance - amt;
    }
    return balance;
  }
  if (ty == "profit" || ty == "profit_entry") {
    return balance + t.amount;
  }
  if (ty == "adjustment") {
    return balance + t.amount;
  }
  if (isFeeType(ty)) {
    return balance - amt;
  }
  return balance;
}

/// Opening balance before [periodStart] (midnight), using all user transactions.
double computeReportOpeningBalance(
  List<TxnItem> allTransactions,
  DateTime periodStart,
) {
  final cutoff = DateTime(periodStart.year, periodStart.month, periodStart.day);
  var balance = 0.0;
  for (final t in allTransactions) {
    if (!t.createdAt.isBefore(cutoff)) continue;
    balance = applyReportTxnToBalance(t, balance);
  }
  return balance;
}

/// Running balance after each txn (chronological [periodTransactions]).
Map<String, double> computeReportBalanceAfterEach(
  List<TxnItem> periodTransactions, {
  required double openingBalance,
}) {
  final sorted = List<TxnItem>.from(periodTransactions)
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  var balance = openingBalance;
  final out = <String, double>{};
  for (final t in sorted) {
    balance = applyReportTxnToBalance(t, balance);
    out[t.id] = balance;
  }
  return out;
}

/// Closing balance after all period transactions (includes hidden fee rows).
double computeReportClosingBalance(
  List<TxnItem> periodTransactions, {
  required double openingBalance,
}) {
  final map = computeReportBalanceAfterEach(
    periodTransactions,
    openingBalance: openingBalance,
  );
  if (map.isEmpty) return openingBalance;
  final sorted = List<TxnItem>.from(periodTransactions)
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return map[sorted.last.id] ?? openingBalance;
}
