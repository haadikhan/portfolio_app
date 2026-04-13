import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "auth_providers.dart";

/// Transaction data class for display (investor-facing).
class TxnItem {
  const TxnItem({
    required this.id,
    required this.type,
    required this.status,
    required this.amount,
    required this.createdAt,
    this.note,
    this.paymentMethod,
    this.proofUrl,
  });

  final String id;

  /// "deposit" | "withdrawal" | "profit_entry" | "profit"
  final String type;

  /// "pending" | "approved" | "rejected"
  final String status;
  final double amount;
  final DateTime createdAt;
  final String? note;
  final String? paymentMethod;
  final String? proofUrl;

  factory TxnItem.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return TxnItem(
      id: doc.id,
      type: (d["type"] as String? ?? "").toLowerCase(),
      status: (d["status"] as String? ?? "pending").toLowerCase(),
      amount: (d["amount"] as num?)?.toDouble() ?? 0,
      createdAt: _parseTime(d["createdAt"]) ?? DateTime.now(),
      note: d["note"] as String?,
      paymentMethod: d["paymentMethod"] as String?,
      proofUrl: d["proofUrl"] as String?,
    );
  }

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString());
  }
}

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
