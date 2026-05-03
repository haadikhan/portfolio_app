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

  bool get hasVerifiedPhone =>
      (verifiedPhone ?? "").trim().isNotEmpty;

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
  });

  final String deviceHash;
  final String deviceName;
  final String platform;
  final String appVersion;
  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;

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
      .map((snap) => snap.docs.map(TrustedDevice.fromDoc).toList());
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
      return snap.exists;
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint(
          "[security] trustedDevice probe error code=${e.code} message=${e.message}",
        );
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
