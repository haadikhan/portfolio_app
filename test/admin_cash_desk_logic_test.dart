import "package:flutter_test/flutter_test.dart";
import "package:portfolio_app/src/admin/cash_desk/cash_desk_logic.dart";
import "package:portfolio_app/src/core/formatting/transaction_display.dart";

void main() {
  test("withdraw full balance text is the available balance", () {
    expect(CashDeskFormLogic.fullBalanceText(1500.5), "1500.50");
    expect(CashDeskFormLogic.fullBalanceText(0), "0.00");
    expect(
      CashDeskFormLogic.validateAmount(amount: 1500.5, available: 1500.5),
      isNull,
    );
    expect(
      CashDeskFormLogic.validateAmount(amount: 1500.51, available: 1500.5),
      isNotNull,
    );
    expect(
      CashDeskFormLogic.validateAmount(amount: 0, available: 100),
      isNotNull,
    );
    expect(
      CashDeskFormLogic.validateAmount(amount: -5, available: 100),
      isNotNull,
    );
  });

  test("actions stay disabled while submitting or blocked", () {
    expect(
      CashDeskFormLogic.actionsEnabled(
        busy: true,
        blocked: false,
        hasInvestor: true,
        walletReady: true,
      ),
      isFalse,
    );
    expect(
      CashDeskFormLogic.actionsEnabled(
        busy: false,
        blocked: true,
        hasInvestor: true,
        walletReady: true,
      ),
      isFalse,
    );
    expect(
      CashDeskFormLogic.actionsEnabled(
        busy: false,
        blocked: false,
        hasInvestor: true,
        walletReady: true,
      ),
      isTrue,
    );
  });

  test("blocked message lists the open requests", () {
    final message = CashDeskFormLogic.blockedMessage(const [
      CashDeskBlocker(kind: "withdrawal", id: "w1", status: "pending"),
      CashDeskBlocker(kind: "deposit", id: "d1", status: "pending"),
    ]);
    expect(message, contains("Resolve open requests first"));
    expect(message, contains("withdrawal w1 (pending)"));
    expect(message, contains("deposit d1 (pending)"));
    expect(
      CashDeskFormLogic.blockersFromTransactions(const [
        {"id": "w1", "type": "withdrawal", "status": "pending"},
        {"id": "ok", "type": "withdrawal", "status": "completed"},
        {"id": "d1", "type": "deposit", "status": "pending"},
      ]).map((b) => b.id),
      ["w1", "d1"],
    );
  });

  test("expected balance moves down for a debit and up for a credit", () {
    expect(
      CashDeskFormLogic.balanceAfter(
        available: 100,
        amount: 40,
        credit: false,
      ),
      60,
    );
    expect(
      CashDeskFormLogic.balanceAfter(
        available: 100,
        amount: 40,
        credit: true,
      ),
      140,
    );
  });

  test("ignores stale deposit_requests when txn is already approved", () {
    final merged = CashDeskFormLogic.mergeBlockers(
      transactions: const [
        {"id": "d9", "type": "deposit", "status": "approved"},
      ],
      withdrawalRequests: const [],
      depositRequests: const [
        {"id": "stale", "status": "pending", "transactionId": "d9"},
      ],
    );
    expect(merged, isEmpty);
  });

  test("mergeBlockers matches server request collections", () {
    final merged = CashDeskFormLogic.mergeBlockers(
      transactions: const [
        {"id": "w1", "type": "withdrawal", "status": "pending"},
      ],
      withdrawalRequests: const [
        {"id": "req-w", "status": "pending", "transactionId": "w1"},
        {"id": "orphan-w", "status": "approved"},
      ],
      depositRequests: const [
        {"id": "orphan-d", "status": "pending"},
      ],
    );
    expect(merged.map((b) => b.id).toList(), ["w1", "orphan-w", "orphan-d"]);
  });

  test("cash desk labels do not change other transaction types", () {
    expect(displayTransactionType("deposit"), "Deposit");
    expect(displayTransactionType("withdrawal"), "Redemption");
    expect(
      displayTransactionType("deposit", source: "admin_cash"),
      "Cash Credit (Admin)",
    );
    expect(
      displayTransactionType("withdrawal", source: "admin_cash"),
      "Cash Debit (Admin)",
    );
    expect(
      displayTransactionType("profit", source: "admin_cash", amount: 5),
      "Daily Profit",
    );
    expect(CashDeskFormLogic.newIdempotencyKey(), matches(RegExp(r"^[A-Za-z0-9_-]{8,128}$")));
  });
}
