import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/app_user.dart";
import "auth_providers.dart";

// ── Extended profile model ────────────────────────────────────────────────────

class InvestorProfile {
  const InvestorProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    this.cnic,
    required this.kycStatus,
    this.bankName,
    this.accountNumber,
    this.accountTitle,
    this.nomineeName,
    this.nomineeCnic,
    this.nomineeRelation,
  });

  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String? cnic;
  final KycLifecycleStatus kycStatus;

  // Bank details
  final String? bankName;
  final String? accountNumber;
  final String? accountTitle;

  // Nominee
  final String? nomineeName;
  final String? nomineeCnic;
  final String? nomineeRelation;

  factory InvestorProfile.fromMap(String uid, Map<String, dynamic> map) {
    final kycRaw = (map["kycStatus"] as String? ?? "pending").toLowerCase();
    final kycStatus = KycLifecycleStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == kycRaw,
      orElse: () => KycLifecycleStatus.pending,
    );
    return InvestorProfile(
      uid: uid,
      name: map["name"] as String? ?? "",
      email: map["email"] as String? ?? "",
      phone: map["phone"] as String?,
      cnic: map["cnic"] as String? ?? map["cnicNumber"] as String?,
      kycStatus: kycStatus,
      bankName: map["bankName"] as String?,
      accountNumber: map["accountNumber"] as String?,
      accountTitle: map["accountTitle"] as String?,
      nomineeName: map["nomineeName"] as String?,
      nomineeCnic: map["nomineeCnic"] as String?,
      nomineeRelation: map["nomineeRelation"] as String?,
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Streams the full investor profile for the signed-in user.
final investorProfileProvider = StreamProvider<InvestorProfile?>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(null);
  return ref
      .read(firebaseFirestoreProvider)
      .collection("users")
      .doc(uid)
      .snapshots()
      .map((snap) {
    if (!snap.exists || snap.data() == null) return null;
    return InvestorProfile.fromMap(uid, snap.data()!);
  });
});

// ── Profile update notifier ───────────────────────────────────────────────────

class ProfileUpdateNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  FirebaseFirestore get _db => ref.read(firebaseFirestoreProvider);

  String get _uid =>
      ref.read(currentUserProvider)?.uid ?? (throw Exception("Not signed in"));

  /// Save freely editable fields (name, phone) directly to users/{uid}.
  Future<void> saveDirectFields({
    String? name,
    String? phone,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final updates = <String, dynamic>{};
      if (name != null && name.isNotEmpty) updates["name"] = name;
      if (phone != null && phone.isNotEmpty) updates["phone"] = phone;
      if (updates.isEmpty) return;
      await _db.collection("users").doc(_uid).update(updates);
    });
  }

  /// Submit bank/nominee change request for admin approval.
  Future<void> submitPendingChange(Map<String, dynamic> requestedFields) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db
          .collection("users")
          .doc(_uid)
          .collection("pendingProfileChanges")
          .add({
        "requestedFields": requestedFields,
        "status": "pending",
        "requestedAt": FieldValue.serverTimestamp(),
        "reviewedAt": null,
        "reviewNote": null,
      });
    });
  }
}

final profileUpdateProvider =
    AsyncNotifierProvider<ProfileUpdateNotifier, void>(
        ProfileUpdateNotifier.new);

// ── Password change (email/password accounts only) ───────────────────────────

class PasswordChangeNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  void reset() {
    state = const AsyncData(null);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authServiceProvider).changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
    });
  }
}

final passwordChangeProvider =
    AsyncNotifierProvider<PasswordChangeNotifier, void>(
        PasswordChangeNotifier.new);
