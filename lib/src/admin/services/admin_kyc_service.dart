import "package:cloud_firestore/cloud_firestore.dart";

import "../models/kyc_admin_models.dart";

/// Admin-side Firestore access for KYC queue and decisions.
class AdminKycService {
  AdminKycService(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _kyc =>
      _db.collection("kyc");
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection("users");

  /// Queue: real submissions only (`kyc/{uid}` with status `underReview` from investor submit).
  Stream<List<KycAdminDocument>> watchPendingKycQueue() {
    return _kyc
        .where("status", isEqualTo: "underReview")
        .snapshots()
        .asyncMap((kycSnap) async {
      final list = <KycAdminDocument>[];

      for (final doc in kycSnap.docs) {
        final uid = doc.id;
        String? name;
        String? phone;
        try {
          final u = await _users.doc(uid).get();
          if (u.exists) {
            final m = u.data()!;
            name = m["name"] as String? ?? "";
            phone = m["phone"] as String? ?? "";
          }
        } catch (_) {}
        list.add(
          KycAdminDocument.fromFirestore(
            uid,
            doc.data(),
            displayName: name,
            phone: phone,
          ),
        );
      }

      list.sort((a, b) {
        final ta = a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  Future<KycAdminDocument?> fetchKycDetail(String userId) async {
    final doc = await _kyc.doc(userId).get();
    String? name;
    String? phone;
    Map<String, dynamic>? userData;
    try {
      final u = await _users.doc(userId).get();
      if (u.exists) {
        userData = u.data()!;
        name = userData["name"] as String? ?? "";
        phone = userData["phone"] as String? ?? "";
      }
    } catch (_) {}

    if (doc.exists && doc.data() != null) {
      return KycAdminDocument.fromFirestore(
        userId,
        doc.data()!,
        displayName: name,
        phone: phone,
      );
    }

    // Rare edge: users.kycStatus synced to underReview but kyc/{uid} missing.
    if (userData != null) {
      final status = (userData["kycStatus"] as String? ?? "").trim();
      if (status == "underReview") {
        return KycAdminDocument.fromFirestore(
          userId,
          {
            "status": status,
            "submittedAt": userData["createdAt"],
          },
          displayName: name,
          phone: phone,
          missingKycFirestoreBody: true,
        );
      }
    }
    return null;
  }

  Future<void> approveKyc(String userId) async {
    final batch = _db.batch();
    final kycRef = _kyc.doc(userId);
    final userRef = _users.doc(userId);
    batch.set(
      kycRef,
      {
        "status": "approved",
        "rejectionReason": null,
        "reviewedAt": FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      userRef,
      {"kycStatus": "approved"},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> rejectKyc(String userId, String reason) async {
    final batch = _db.batch();
    final kycRef = _kyc.doc(userId);
    final userRef = _users.doc(userId);
    batch.set(
      kycRef,
      {
        "status": "rejected",
        "rejectionReason": reason.trim(),
        "reviewedAt": FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      userRef,
      {"kycStatus": "rejected"},
      SetOptions(merge: true),
    );
    await batch.commit();
  }
}
