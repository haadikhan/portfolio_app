import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../services/wallet_ledger_functions_service.dart";
import "auth_providers.dart";

final walletLedgerFunctionsProvider = Provider<WalletLedgerFunctionsService>(
  (_) => WalletLedgerFunctionsService(),
);

/// Server-derived wallet projection for the signed-in user.
final userWalletStreamProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<Map<String, dynamic>?>.value(null);
  }
  return ref.read(firebaseFirestoreProvider).collection("wallets").doc(uid).snapshots().map(
        (s) => s.exists ? s.data() : null,
      );
});

/// Ledger entries for the signed-in user (newest first).
final userTransactionsStreamProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>?>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<QuerySnapshot<Map<String, dynamic>>?>.value(null);
  }
  return ref
      .read(firebaseFirestoreProvider)
      .collection("transactions")
      .where("userId", isEqualTo: uid)
      .orderBy("createdAt", descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s);
});
