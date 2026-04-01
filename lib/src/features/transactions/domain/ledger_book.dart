import "dart:collection";

import "transaction_entity.dart";

class LedgerBook {
  LedgerBook([Iterable<TransactionEntity>? initial])
      : _transactions = List.unmodifiable(initial ?? const []);

  final List<TransactionEntity> _transactions;

  UnmodifiableListView<TransactionEntity> get transactions =>
      UnmodifiableListView(_transactions);

  LedgerBook append(TransactionEntity tx) {
    return LedgerBook([..._transactions, tx]);
  }

  // Immutable ledger: no delete operation by design.
}
