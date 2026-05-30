import "package:cloud_firestore/cloud_firestore.dart";

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
    this.silentFee = false,
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

  /// v2 daily management fee — hidden from investor transaction history.
  final bool silentFee;

  factory TxnItem.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final noteSingular = (d["note"] as String?)?.trim();
    final notePlural = (d["notes"] as String?)?.trim();
    final note = noteSingular != null && noteSingular.isNotEmpty
        ? noteSingular
        : (notePlural != null && notePlural.isNotEmpty ? notePlural : null);

    return TxnItem(
      id: doc.id,
      type: (d["type"] as String? ?? "").toLowerCase(),
      status: (d["status"] as String? ?? "pending").toLowerCase(),
      amount: (d["amount"] as num?)?.toDouble() ?? 0,
      createdAt: _parseTime(d["createdAt"]) ?? DateTime.now(),
      note: note,
      paymentMethod: d["paymentMethod"] as String?,
      proofUrl: d["proofUrl"] as String?,
      silentFee: d["silentFee"] == true,
    );
  }

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString());
  }
}
