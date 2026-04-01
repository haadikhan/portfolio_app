import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "auth_providers.dart";

/// A single investor report document from Firestore reports/ collection.
class ReportItem {
  const ReportItem({
    required this.id,
    required this.title,
    required this.month,
    required this.year,
    required this.fileUrl,
    required this.createdAt,
    this.uid,
  });

  final String id;
  final String title;
  final String month;
  final int year;
  final String fileUrl;
  final DateTime createdAt;

  /// null or "all" means global report visible to everyone.
  final String? uid;

  factory ReportItem.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return ReportItem(
      id: doc.id,
      title: d["title"] as String? ?? "Report",
      month: d["month"] as String? ?? "",
      year: (d["year"] as num?)?.toInt() ?? DateTime.now().year,
      fileUrl: d["fileUrl"] as String? ?? "",
      createdAt: _parseTime(d["createdAt"]) ?? DateTime.now(),
      uid: d["uid"] as String?,
    );
  }

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString());
  }
}

/// Streams reports for the signed-in user (own reports + global "all" reports).
final userReportsProvider = StreamProvider<List<ReportItem>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value([]);
  // Firestore doesn't support OR queries on different fields in one query,
  // so we fetch all and filter client-side (report collection is typically small).
  return ref
      .read(firebaseFirestoreProvider)
      .collection("reports")
      .orderBy("createdAt", descending: true)
      .snapshots()
      .map((snap) {
    return snap.docs
        .map(ReportItem.fromDoc)
        .where((r) => r.uid == null || r.uid == "all" || r.uid == uid)
        .toList();
  });
});
