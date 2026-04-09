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

  /// Pending queue: submissions awaiting review (includes legacy `pending` and active `underReview`).
  Stream<List<KycAdminDocument>> watchPendingKycQueue() {
    return _kyc
        .where("status", whereIn: ["pending", "underReview"])
        .snapshots()
        .asyncMap((kycSnap) async {
      final list = <KycAdminDocument>[];
      final seenUserIds = <String>{};

      for (final doc in kycSnap.docs) {
        final uid = doc.id;
        seenUserIds.add(uid);
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

      // Legacy fallback: include users that still have pending KYC status on
      // users/{uid} but no corresponding kyc/{uid} doc from older/broken flows.
      final legacyUsers = await _users
          .where("kycStatus", whereIn: ["pending", "underReview"])
          .get();
      for (final u in legacyUsers.docs) {
        if (seenUserIds.contains(u.id)) continue;
        final m = u.data();
        final status = (m["kycStatus"] as String? ?? "pending").trim();
        list.add(
          KycAdminDocument.fromFirestore(
            u.id,
            {
              "status": status.isEmpty ? "pending" : status,
              "submittedAt": m["createdAt"],
            },
            displayName: m["name"] as String? ?? "",
            phone: m["phone"] as String? ?? "",
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

    // Legacy fallback: old records may be pending in users/{uid} without a
    // kyc/{uid} document. Return a synthetic review model instead of null.
    if (userData != null) {
      final status = (userData["kycStatus"] as String? ?? "").trim();
      if (status == "pending" || status == "underReview") {
        return KycAdminDocument.fromFirestore(
          userId,
          {
            "status": status,
            "submittedAt": userData["createdAt"],
          },
          displayName: name,
          phone: phone,
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
