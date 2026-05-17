import "package:flutter_riverpod/flutter_riverpod.dart";

import "../features/investor/data/models/txn_item.dart";
import "auth_providers.dart";

export "../features/investor/data/models/txn_item.dart";

/// Streams all transactions for the signed-in user, newest first.
final userTransactionItemsProvider = StreamProvider<List<TxnItem>>((ref) {
  return authBoundFirestoreStream<List<TxnItem>>(
    ref,
    whenSignedOut: const [],
    body: (user) => ref
        .read(firebaseFirestoreProvider)
        .collection("transactions")
        .where("userId", isEqualTo: user.uid)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(TxnItem.fromDoc).toList()),
  );
});
