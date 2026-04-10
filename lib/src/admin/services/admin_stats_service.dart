import "package:cloud_firestore/cloud_firestore.dart";

class AdminStatsService {
  AdminStatsService(this._db);

  final FirebaseFirestore _db;

  /// Total user documents in `users`.
  Future<int> countUsers() async {
    final q = await _db.collection("users").count().get();
    return q.count ?? 0;
  }

  /// Counts `kyc` docs awaiting staff action (matches admin KYC queue).
  Future<int> countPendingKyc() async {
    final underReview = await _db
        .collection("kyc")
        .where("status", isEqualTo: "underReview")
        .count()
        .get();
    return underReview.count ?? 0;
  }
}
