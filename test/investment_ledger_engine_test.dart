import "package:flutter_test/flutter_test.dart";
import "package:portfolio_app/src/architecture_foundation.dart";

void main() {
  const engine = InvestmentLedgerEngine();

  test("deposit requires admin approval before wallet updates", () {
    final pending = engine.requestDeposit(
      txId: "TXN-1",
      userId: "U-1",
      amount: 100000,
    );
    final ledgerPending = LedgerBook().append(pending);
    final beforeApproval = engine.calculateWallet(
      userId: "U-1",
      ledger: ledgerPending,
    );
    expect(beforeApproval.balance, 0);

    final approved = engine.approveDeposit(pending);
    final ledgerApproved = LedgerBook().append(approved);
    final afterApproval = engine.calculateWallet(
      userId: "U-1",
      ledger: ledgerApproved,
    );
    expect(afterApproval.balance, 100000);
  });

  test("withdrawal flow checks available balance and deducts on completion", () {
    final startingLedger = LedgerBook().append(
      TransactionEntity(
        id: "TXN-D",
        userId: "U-1",
        type: TransactionType.deposit,
        amount: 100000,
        status: TransactionStatus.approved,
        createdAt: DateTime.now(),
      ),
    );
    final wallet = engine.calculateWallet(userId: "U-1", ledger: startingLedger);

    final withdrawal = engine.requestWithdrawal(
      txId: "TXN-W",
      userId: "U-1",
      amount: 20000,
      wallet: wallet,
      reservedAmount: 0,
    );
    final approved = engine.approveWithdrawal(withdrawal);
    final completed = engine.completeWithdrawal(approved);

    final finalWallet = engine.calculateWallet(
      userId: "U-1",
      ledger: startingLedger.append(completed),
    );
    expect(finalWallet.balance, 80000);
  });

  test("profit is admin-entered and marked non-guaranteed", () {
    final ledger = LedgerBook().append(
      TransactionEntity(
        id: "TXN-D",
        userId: "U-1",
        type: TransactionType.deposit,
        amount: 100000,
        status: TransactionStatus.approved,
        createdAt: DateTime.now(),
      ),
    );
    final wallet = engine.calculateWallet(userId: "U-1", ledger: ledger);

    final profitTx = engine.createProfitTransaction(
      txId: "TXN-P",
      userId: "U-1",
      percentage: 5,
      wallet: wallet,
      notes: "Monthly return",
    );

    expect(profitTx.amount, 5000);
    expect(profitTx.notes, contains("Indicative/Admin-entered/Not guaranteed"));
  });
}
