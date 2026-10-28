import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:rxdart/rxdart.dart";

import "../../providers/auth_providers.dart";
import "../cash_desk/cash_desk_logic.dart";
import "../services/admin_cash_desk_service.dart";

final adminCashDeskServiceProvider = Provider<CashDeskCaller>(
  (ref) => AdminCashDeskService(),
);

class CashDeskEntry {
  const CashDeskEntry({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.createdAt,
    required this.adminUid,
  });

  final String id;
  final String userId;
  final String type;
  final double amount;
  final DateTime? createdAt;
  final String adminUid;
}

final cashDeskWalletProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, uid) {
  return ref.watch(firebaseFirestoreProvider).collection("wallets").doc(uid).snapshots().map(
        (s) => s.data(),
      );
});

final cashDeskBlockersProvider =
    StreamProvider.family<List<CashDeskBlocker>, String>((ref, uid) {
  final fs = ref.watch(firebaseFirestoreProvider);
  final tx$ = fs
      .collection("transactions")
      .where("userId", isEqualTo: uid)
      .snapshots();
  final wr$ = fs
      .collection("withdrawal_requests")
      .where("userId", isEqualTo: uid)
      .snapshots();
  final dr$ = fs
      .collection("deposit_requests")
      .where("userId", isEqualTo: uid)
      .snapshots();
  return Rx.combineLatest3(tx$, wr$, dr$, (tx, wr, dr) {
    return CashDeskFormLogic.mergeBlockers(
      transactions: tx.docs.map((d) => {...d.data(), "id": d.id}),
      withdrawalRequests: wr.docs.map((d) => {...d.data(), "id": d.id}),
      depositRequests: dr.docs.map((d) => {...d.data(), "id": d.id}),
    );
  });
});

final cashDeskPortfolioNumberProvider = FutureProvider.family<String, String>((
  ref,
  uid,
) async {
  final doc = await ref
      .watch(firebaseFirestoreProvider)
      .collection("users")
      .doc(uid)
      .get();
  return (doc.data()?["portfolioNumber"] as String?)?.trim() ?? "";
});

final cashDeskRecentProvider = StreamProvider<List<CashDeskEntry>>((ref) {
  return ref
      .watch(firebaseFirestoreProvider)
      .collection("transactions")
      .where("metadata.source", isEqualTo: "admin_cash")
      .orderBy("createdAt", descending: true)
      .limit(40)
      .snapshots()
      .map((snap) => snap.docs.map(_entryFromDoc).toList());
});

CashDeskEntry _entryFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final d = doc.data();
  final created = d["createdAt"];
  DateTime? at;
  if (created is Timestamp) at = created.toDate();
  final adminUid = (d["completedBy"] ?? d["approvedBy"] ?? "").toString();
  return CashDeskEntry(
    id: doc.id,
    userId: (d["userId"] ?? "").toString(),
    type: (d["type"] ?? "").toString(),
    amount: (d["amount"] as num?)?.toDouble() ?? 0,
    createdAt: at,
    adminUid: adminUid,
  );
}
