import "package:cloud_firestore/cloud_firestore.dart";

class AdminStatsService {
  AdminStatsService(this._db);

  final FirebaseFirestore _db;

  /// Total user documents in `users`.
  Future<int> countUsers() async {
    final q = await _db.collection("users").count().get();
    return q.count ?? 0;
  }

  /// KYC submissions awaiting decision.
  Future<int> countPendingKyc() async {
    final pending = await _db
        .collection("kyc")
        .where("status", isEqualTo: "pending")
        .count()
        .get();
    final review = await _db
        .collection("kyc")
        .where("status", isEqualTo: "underReview")
        .count()
        .get();
    return (pending.count ?? 0) + (review.count ?? 0);
  }
}
