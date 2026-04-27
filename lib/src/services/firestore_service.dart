import "dart:async";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/foundation.dart";

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

  /// After email/password sign-in, the Auth user exists before Firestore always honors
  /// `request.auth` on reads. Retries a server [get] on [users] until rules accept it
  /// (matches login → immediate navigation → `permission-denied` on listeners).
  Future<void> waitUntilUserDocAccessible(User user) async {
    const maxAttempts = 8;
    const perAttemptTimeout = Duration(seconds: 3);
    const maxTotalWait = Duration(seconds: 12);
    final stopwatch = Stopwatch()..start();
    FirebaseException? lastRetryable;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (stopwatch.elapsed >= maxTotalWait) {
        break;
      }
      try {
        await user.getIdToken(true).timeout(perAttemptTimeout);
        await _users
            .doc(user.uid)
            .get(const GetOptions(source: Source.server))
            .timeout(perAttemptTimeout);
        return;
      } on TimeoutException {
        lastRetryable = FirebaseException(
          plugin: "cloud_firestore",
          code: "deadline-exceeded",
          message: "Timed out while waiting for Firestore access.",
        );
      } on FirebaseException catch (e) {
        final retryable =
            e.code == "permission-denied" ||
            e.code == "unavailable" ||
            e.code == "deadline-exceeded";
        if (!retryable) {
          rethrow;
        }
        lastRetryable = e;
        if (attempt < maxAttempts - 1) {
          await Future<void>.delayed(
            Duration(milliseconds: 120 * (attempt + 1)),
          );
          continue;
        }
      }
    }

    // Avoid blocking login indefinitely on unstable/offline networks.
    if (kDebugMode) {
      debugPrint(
        "[AUTH][Firestore] Continuing without server accessibility confirmation. "
        "elapsed=${stopwatch.elapsed.inMilliseconds}ms "
        "lastCode=${lastRetryable?.code} lastMessage=${lastRetryable?.message}",
      );
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
      final email = (existing.data()!["email"] as String?)?.trim() ?? "";
      // FCM may have created users/{uid} with only fcmTokens; still merge profile fields.
      if (email.isNotEmpty) {
        return;
      }
    }

    final fallbackName = user.displayName?.trim();
    final email = user.email?.trim() ?? "";
    // Use auth creation timestamp so concurrent bootstrap writes stay identical.
    final createdAtIso =
        user.metadata.creationTime?.toIso8601String() ??
        DateTime.now().toIso8601String();
    await ref.set({
      "email": email,
      "name": (fallbackName == null || fallbackName.isEmpty)
          ? (email.contains("@") ? email.split("@").first : "Investor")
          : fallbackName,
      "createdAt": createdAtIso,
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
    required String address,
    required String bankName,
    required String nomineeName,
    required String nomineeCnic,
    required String nomineeRelation,
    String? ibanOrAccountNumber,
    String? accountTitle,
    String? cnicFrontUrl,
    String? cnicBackUrl,
    String? selfieUrl,
    Map<String, dynamic>? paymentProof,
  }) async {
    final cnic = cnicNumber.trim();
    final phoneClean = phone.trim();
    final addressClean = address.trim();
    final bankNameClean = bankName.trim();
    final nomineeNameClean = nomineeName.trim();
    final nomineeCnicClean = nomineeCnic.trim();
    final nomineeRelationClean = nomineeRelation.trim();
    final ibanClean = ibanOrAccountNumber?.trim();
    final accountTitleClean = accountTitle?.trim();
    if (cnic.isEmpty ||
        phoneClean.isEmpty ||
        addressClean.isEmpty ||
        bankNameClean.isEmpty ||
        nomineeNameClean.isEmpty ||
        nomineeCnicClean.isEmpty ||
        nomineeRelationClean.isEmpty) {
      throw Exception("KYC required fields are missing.");
    }
    try {
      final batch = _db.batch();
      batch.set(_kyc.doc(userId), {
        "cnicNumber": cnic,
        "phone": phoneClean,
        "address": addressClean,
        "bankName": bankNameClean,
        "nomineeName": nomineeNameClean,
        "nomineeCnic": nomineeCnicClean,
        "nomineeRelation": nomineeRelationClean,
        if (ibanClean != null && ibanClean.isNotEmpty)
          "ibanOrAccountNumber": ibanClean,
        if (accountTitleClean != null && accountTitleClean.isNotEmpty)
          "accountTitle": accountTitleClean,
        "cnicFrontUrl": cnicFrontUrl?.trim().isEmpty == true
            ? null
            : cnicFrontUrl?.trim(),
        "cnicBackUrl": cnicBackUrl?.trim().isEmpty == true
            ? null
            : cnicBackUrl?.trim(),
        "selfieUrl": selfieUrl?.trim().isEmpty == true
            ? null
            : selfieUrl?.trim(),
        if (paymentProof != null) "paymentProof": paymentProof,
        "status": "underReview",
        "rejectionReason": null,
        "submittedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(_users.doc(userId), {
        "phone": phoneClean,
        "kycStatus": KycLifecycleStatus.underReview.name,
      }, SetOptions(merge: true));
      await batch.commit();
    } on FirebaseException catch (e) {
      final msg = e.message?.trim();
      throw Exception(
        "Failed to submit KYC. [${e.code}]${msg != null && msg.isNotEmpty ? " $msg" : ""}",
      );
    } catch (e) {
      throw Exception("Failed to submit KYC: $e");
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
    batch.set(_consents.doc(userId), {
      "userId": userId,
      "accepted": true,
      "acceptedAt": FieldValue.serverTimestamp(),
      "version": kConsentDocumentVersion,
    }, SetOptions(merge: true));
    final eventRef = _users.doc(userId).collection("consent_events").doc();
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
