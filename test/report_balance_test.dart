import "package:flutter_test/flutter_test.dart";
import "package:portfolio_app/src/features/investor/data/models/txn_item.dart";
import "package:portfolio_app/src/features/reports/services/report_balance.dart";

void main() {
  test("closing balance subtracts silent fees hidden from display rows", () {
    final txns = [
      TxnItem(
        id: "dep",
        type: "deposit",
        status: "approved",
        amount: 100_000,
        createdAt: DateTime(2026, 10, 1),
      ),
      TxnItem(
        id: "fee",
        type: "management_fee",
        status: "approved",
        amount: 8_000,
        createdAt: DateTime(2026, 10, 5),
        silentFee: true,
      ),
      TxnItem(
        id: "wdr",
        type: "withdrawal",
        status: "completed",
        amount: 92_000,
        createdAt: DateTime(2026, 10, 10),
      ),
    ];

    final closing = computeReportClosingBalance(txns, openingBalance: 0);
    expect(closing, closeTo(0, 0.01));
  });

  test("balance after map applies hidden fee before visible withdrawal", () {
    final txns = [
      TxnItem(
        id: "fee",
        type: "management_fee",
        status: "approved",
        amount: 100,
        createdAt: DateTime(2026, 10, 1, 9),
        silentFee: true,
      ),
      TxnItem(
        id: "wdr",
        type: "withdrawal",
        status: "completed",
        amount: 900,
        createdAt: DateTime(2026, 10, 1, 10),
      ),
    ];

    final map = computeReportBalanceAfterEach(txns, openingBalance: 1000);
    expect(map["wdr"], closeTo(0, 0.01));
  });
}
