import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../providers/auth_providers.dart";
import "../../../services/device_fingerprint.dart";

bool _firestoreUnavailableOrTransient(FirebaseException e) {
  switch (e.code) {
    case "unavailable":
    case "deadline-exceeded":
    case "aborted":
    case "resource-exhausted":
      return true;
    default:
      return false;
  }
}

class UserSecurityState {
  const UserSecurityState({
    required this.verifiedPhone,
    required this.verifiedPhoneAt,
  });

  final String? verifiedPhone;
  final DateTime? verifiedPhoneAt;

  bool get hasVerifiedPhone => (verifiedPhone ?? "").trim().isNotEmpty;

  factory UserSecurityState.fromUserDoc(Map<String, dynamic>? data) {
    final security = (data?["security"] as Map<String, dynamic>?) ?? const {};
    final ts = security["verifiedPhoneAt"];
    return UserSecurityState(
      verifiedPhone: (security["verifiedPhone"] as String?)?.trim(),
      verifiedPhoneAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

class TrustedDevice {
  const TrustedDevice({
    required this.deviceHash,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.revoked,
    required this.revokedAt,
  });

  final String deviceHash;
  final String deviceName;
  final String platform;
  final String appVersion;
  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;
  final bool revoked;
  final DateTime? revokedAt;

  factory TrustedDevice.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    DateTime? asDate(dynamic v) => v is Timestamp ? v.toDate() : null;
    return TrustedDevice(
      deviceHash: ((d["deviceHash"] as String?) ?? doc.id).trim(),
      deviceName: ((d["deviceName"] as String?) ?? "").trim(),
      platform: ((d["platform"] as String?) ?? "").trim(),
      appVersion: ((d["appVersion"] as String?) ?? "").trim(),
      firstSeenAt: asDate(d["firstSeenAt"]),
      lastSeenAt: asDate(d["lastSeenAt"]),
      revoked: (d["revoked"] as bool?) ?? false,
      revokedAt: asDate(d["revokedAt"]),
    );
  }
}

final userSecurityProvider = StreamProvider<UserSecurityState?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection("users")
      .doc(user.uid)
      .snapshots()
      .map((doc) => UserSecurityState.fromUserDoc(doc.data()));
});

final currentDeviceFingerprintProvider = FutureProvider<DeviceFingerprint?>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return currentDeviceFingerprint(user.uid);
});

final trustedDevicesStreamProvider = StreamProvider<List<TrustedDevice>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return FirebaseFirestore.instance
      .collection("users")
      .doc(user.uid)
      .collection("trustedDevices")
      .orderBy("lastSeenAt", descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map(TrustedDevice.fromDoc)
            .where((d) => !d.revoked)
            .toList(),
      );
});

/// True when this device's own `trustedDevices/{deviceHash}` doc has `revoked: true`.
///
/// Uses [includeMetadataChanges] and skips cache-only snapshots so a stale
/// offline-cache value of `revoked: true` never triggers an immediate sign-out
/// on the next login before the server has had a chance to respond.
final currentDeviceRevokedProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(false);

  final fpAsync = ref.watch(currentDeviceFingerprintProvider);
  return fpAsync.when(
    data: (fp) {
      if (fp == null) return Stream.value(false);
      return ref
          .read(firebaseFirestoreProvider)
          .collection("users")
          .doc(user.uid)
          .collection("trustedDevices")
          .doc(fp.deviceHash)
          .snapshots(includeMetadataChanges: true)
          .where((snap) => !snap.metadata.isFromCache)
          .map((snap) {
            if (!snap.exists) return false;
            return (snap.data()?["revoked"] as bool?) ?? false;
          });
    },
    loading: () => Stream.value(false),
    error: (_, _) => Stream.value(false),
  );
});

final currentDeviceTrustedProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  final fp = await ref.watch(currentDeviceFingerprintProvider.future);
  if (fp == null) return false;
  final trustedDeviceDoc = FirebaseFirestore.instance
      .collection("users")
      .doc(user.uid)
      .collection("trustedDevices")
      .doc(fp.deviceHash);

  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      DocumentSnapshot<Map<String, dynamic>> snap;
      try {
        snap = await trustedDeviceDoc.get(
          const GetOptions(source: Source.server),
        );
      } on FirebaseException catch (e) {
        if (e.code == "unavailable" || e.code == "failed-precondition") {
          snap = await trustedDeviceDoc.get();
        } else if (e.code == "permission-denied") {
          if (kDebugMode) {
            debugPrint(
              "[security] trustedDevice probe permission-denied on get; "
              "treating as not trusted",
            );
          }
          return false;
        } else {
          rethrow;
        }
      }
      if (kDebugMode) {
        debugPrint(
          "[security] trustedDevice probe uid=${user.uid} "
          "hash=${fp.deviceHash} exists=${snap.exists}",
        );
      }
      if (!snap.exists) return false;
      return !((snap.data()?["revoked"] as bool?) ?? false);
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint(
          "[security] trustedDevice probe error code=${e.code} message=${e.message}",
        );
      }
      if (e.code == "permission-denied") {
        return false;
      }
      if (!_firestoreUnavailableOrTransient(e)) rethrow;
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        continue;
      }
      if (kDebugMode) {
        debugPrint(
          "[security] trustedDevices probe failed (${e.code}); "
          "treating device as trusted so startup can proceed",
        );
      }
      return true;
    }
  }
  // All attempts either returned or rethrew; satisfy flow analysis.
  return false;
});

/// True when the verified-phone OTP challenge should run: device is not yet
/// in [trustedDevices] for this fingerprint (new / untrusted device only).
final otpRequiredProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final trusted = await ref.watch(currentDeviceTrustedProvider.future);
  return !trusted;
});
