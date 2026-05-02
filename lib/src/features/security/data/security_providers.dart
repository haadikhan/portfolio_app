import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../providers/auth_providers.dart";
import "../../../services/device_fingerprint.dart";

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
  final snap = await FirebaseFirestore.instance
      .collection("users")
      .doc(user.uid)
      .collection("trustedDevices")
      .doc(fp.deviceHash)
      .get();
  return snap.exists;
});

DateTime? _timestampToDate(dynamic v) => v is Timestamp ? v.toDate() : null;

/// True when the verified-phone OTP challenge should run: new/untrusted device,
/// or password/MPIN changed since this device was last confirmed via OTP.
final otpRequiredProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final trusted = await ref.watch(currentDeviceTrustedProvider.future);
  if (!trusted) return true;

  final fp = await ref.watch(currentDeviceFingerprintProvider.future);
  if (fp == null) return true;

  final deviceSnap = await FirebaseFirestore.instance
      .collection("users")
      .doc(user.uid)
      .collection("trustedDevices")
      .doc(fp.deviceHash)
      .get();

  final lastSeenAt = _timestampToDate(deviceSnap.data()?["lastSeenAt"]);

  final userSnap = await FirebaseFirestore.instance
      .collection("users")
      .doc(user.uid)
      .get();
  final data = userSnap.data();
  if (data == null) return false;

  final security = data["security"] as Map<String, dynamic>?;
  final passwordChangedAt = _timestampToDate(security?["passwordChangedAt"]);
  final mpinUpdatedAt = _timestampToDate(data["mpinUpdatedAt"]);

  bool credentialNewerThanLastTrust(DateTime? credentialTime) {
    if (credentialTime == null) return false;
    if (lastSeenAt == null) return true;
    return credentialTime.isAfter(lastSeenAt);
  }

  if (credentialNewerThanLastTrust(passwordChangedAt)) return true;
  if (credentialNewerThanLastTrust(mpinUpdatedAt)) return true;

  return false;
});
