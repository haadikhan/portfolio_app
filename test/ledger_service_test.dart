import "package:flutter_test/flutter_test.dart";
import "package:portfolio_app/src/core/models/domain_models.dart";
import "package:portfolio_app/src/core/services/ledger_service.dart";

void main() {
  const service = LedgerService();

  test("wallet derived from approved/completed transactions", () {
    final wallet = service.deriveWallet([
      LedgerTransaction(
        id: "1",
        userId: "u1",
        type: TransactionType.deposit,
        status: TransactionStatus.approved,
        amount: 100000,
        createdAt: DateTime(2026, 1, 1),
      ),
      LedgerTransaction(
        id: "2",
        userId: "u1",
        type: TransactionType.profit,
        status: TransactionStatus.approved,
        amount: 5000,
        createdAt: DateTime(2026, 1, 30),
      ),
      LedgerTransaction(
        id: "3",
        userId: "u1",
        type: TransactionType.withdrawal,
        status: TransactionStatus.pending,
        amount: 10000,
        createdAt: DateTime(2026, 2, 1),
      ),
    ]);

    expect(wallet.totalDeposited, 100000);
    expect(wallet.totalProfit, 5000);
    expect(wallet.reservedAmount, 10000);
    expect(wallet.currentBalance, 95000);
  });

  test("monthly return is idempotent for same cycle", () {
    final existing = [
      LedgerTransaction(
        id: "1",
        userId: "u1",
        type: TransactionType.deposit,
        status: TransactionStatus.approved,
        amount: 100000,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];

    final first = service.applyMonthlyReturn(
      existing: existing,
      percentage: 5,
      cycleDate: DateTime(2026, 2, 1),
    );
    final second = service.applyMonthlyReturn(
      existing: first,
      percentage: 5,
      cycleDate: DateTime(2026, 2, 15),
    );

    expect(first.length, 2);
    expect(second.length, 2);
  });
}
