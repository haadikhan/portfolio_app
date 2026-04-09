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
    final pendingKycDocs = await _db
        .collection("kyc")
        .where("status", isEqualTo: "pending")
        .count()
        .get();
    final underReviewKycDocs = await _db
        .collection("kyc")
        .where("status", isEqualTo: "underReview")
        .count()
        .get();

    // Legacy fallback: include users marked pending/underReview in users/{uid}
    // that still do not have a corresponding kyc/{uid} document.
    final pendingUsers = await _db
        .collection("users")
        .where("kycStatus", whereIn: ["pending", "underReview"])
        .get();
    int legacyWithoutKyc = 0;
    for (final userDoc in pendingUsers.docs) {
      final kycDoc = await _db.collection("kyc").doc(userDoc.id).get();
      if (!kycDoc.exists) {
        legacyWithoutKyc++;
      }
    }

    return (pendingKycDocs.count ?? 0) +
        (underReviewKycDocs.count ?? 0) +
        legacyWithoutKyc;
  }
}
