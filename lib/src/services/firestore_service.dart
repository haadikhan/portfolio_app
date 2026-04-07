import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";

import "../core/compliance/consent_version.dart";
import "../models/app_user.dart";
import "../models/user_kyc.dart";

class FirestoreService {
  FirestoreService(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection("users");
  CollectionReference<Map<String, dynamic>> get _kyc => _db.collection("kyc");
  CollectionReference<Map<String, dynamic>> get _consents =>
      _db.collection("consents");

  Future<void> createUserProfile(AppUser user) async {
    try {
      await _users.doc(user.id).set(user.toMap(), SetOptions(merge: true));
    } catch (_) {
      throw Exception("Could not create user profile.");
    }
  }

  Future<AppUser?> fetchUser(String userId) async {
    try {
      final doc = await _users.doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromMap(doc.id, doc.data()!);
    } catch (_) {
      throw Exception("Failed to fetch user data.");
    }
  }

  Future<void> updateUserProfile({
    required String userId,
    required String name,
  }) async {
    try {
      await _users.doc(userId).update({"name": name.trim()});
    } catch (_) {
      throw Exception("Failed to update profile.");
    }
  }

  Stream<AppUser?> streamUser(String userId) {
    return _users.doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromMap(doc.id, doc.data()!);
    });
  }

  /// Ensures a signed-in auth user always has a Firestore profile doc.
  /// This keeps restart/login flows stable for legacy accounts that were
  /// created before profile bootstrap existed.
  Future<void> ensureUserProfileFromAuthUser(User user) async {
    final ref = _users.doc(user.uid);
    final existing = await ref.get();
    if (existing.exists && existing.data() != null) {
      return;
    }

    final fallbackName = user.displayName?.trim();
    final email = user.email?.trim() ?? "";
    await ref.set({
      "email": email,
      "name": (fallbackName == null || fallbackName.isEmpty)
          ? (email.contains("@") ? email.split("@").first : "Investor")
          : fallbackName,
      "createdAt": DateTime.now().toIso8601String(),
      "kycStatus": "pending",
    }, SetOptions(merge: true));
  }

  Stream<UserKycRecord?> streamUserKyc(String userId) {
    return _kyc.doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserKycRecord.fromMap(doc.id, doc.data()!);
    });
  }

  Future<void> submitKyc({
    required String userId,
    required String cnicNumber,
    required String phone,
    String? cnicFrontUrl,
    String? cnicBackUrl,
    String? selfieUrl,
  }) async {
    final cnic = cnicNumber.trim();
    final phoneClean = phone.trim();
    if (cnic.isEmpty || phoneClean.isEmpty) {
      throw Exception("CNIC and phone are required.");
    }
    try {
      final batch = _db.batch();
      batch.set(_kyc.doc(userId), {
        "cnicNumber": cnic,
        "phone": phoneClean,
        "cnicFrontUrl": cnicFrontUrl?.trim().isEmpty == true
            ? null
            : cnicFrontUrl?.trim(),
        "cnicBackUrl": cnicBackUrl?.trim().isEmpty == true
            ? null
            : cnicBackUrl?.trim(),
        "selfieUrl": selfieUrl?.trim().isEmpty == true
            ? null
            : selfieUrl?.trim(),
        "status": "underReview",
        "rejectionReason": null,
        "submittedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(_users.doc(userId), {
        "phone": phoneClean,
      }, SetOptions(merge: true));
      await batch.commit();
    } catch (_) {
      throw Exception("Failed to submit KYC.");
    }
  }

  Future<void> persistConsent({
    required String userId,
    required bool accepted,
  }) async {
    if (!accepted) {
      throw Exception("Consent must be accepted.");
    }
    final batch = _db.batch();
    batch.set(
      _consents.doc(userId),
      {
        "userId": userId,
        "accepted": true,
        "acceptedAt": FieldValue.serverTimestamp(),
        "version": kConsentDocumentVersion,
      },
      SetOptions(merge: true),
    );
    final eventRef =
        _users.doc(userId).collection("consent_events").doc();
    batch.set(eventRef, {
      "userId": userId,
      "version": kConsentDocumentVersion,
      "acceptedAt": FieldValue.serverTimestamp(),
      "source": "in_app_legal",
    });
    await batch.commit();
  }

  Stream<bool> streamConsentAccepted(String userId) {
    return _consents.doc(userId).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return false;
      final accepted = data["accepted"] == true;
      final version = data["version"] as String? ?? "v1";
      return accepted && version == kConsentDocumentVersion;
    });
  }
}
