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

  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      DocumentSnapshot<Map<String, dynamic>> snap;
      try {
        // 8-second per-attempt cap — prevents each Firebase SDK call from
        // blocking for its default ~60 s before we can retry or fall back.
        snap = await trustedDeviceDoc
            .get(const GetOptions(source: Source.server))
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () => throw FirebaseException(
                plugin: "cloud_firestore",
                code: "deadline-exceeded",
                message: "trustedDevice probe timed out",
              ),
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
      if (attempt < 4) {
        // Short back-off between retries: 300ms, 600ms, 1000ms, 1500ms.
        // Total worst-case before cache fallback: ~12 s (4×8 s probe + back-off).
        const delays = [300, 600, 1000, 1500];
        await Future<void>.delayed(
          Duration(milliseconds: delays[attempt]),
        );
        continue;
      }
      // All server attempts failed (likely Play Integrity / App Check
      // not yet initialized at startup). Try local cache as last resort.
      // A cached "trusted" value from a recent successful session is
      // more reliable than blindly requiring OTP on every startup.
      if (kDebugMode) {
        debugPrint(
          "[security] trustedDevices server probe failed after all retries "
          "(${e.code}). Trying local cache as fallback.",
        );
      }
      try {
        final cachedSnap = await trustedDeviceDoc.get(
          const GetOptions(source: Source.cache),
        );
        if (!cachedSnap.exists) {
          if (kDebugMode) {
            debugPrint(
              "[security] No cached trust doc found. Requiring OTP.",
            );
          }
          return false;
        }
        final revokedInCache =
            (cachedSnap.data()?["revoked"] as bool?) ?? false;
        if (revokedInCache) {
          if (kDebugMode) {
            debugPrint(
              "[security] Cached doc shows revoked=true. Requiring OTP.",
            );
          }
          return false;
        }
        if (kDebugMode) {
          debugPrint(
            "[security] Using cached trust doc — device appears trusted. "
            "OTP skipped. Server will reconfirm on next refresh.",
          );
        }
        return true;
      } catch (_) {
        if (kDebugMode) {
          debugPrint(
            "[security] Cache read also failed. Requiring OTP.",
          );
        }
        return false;
      }
    }
  }
  // Exhausted retries — require OTP rather than falsely trusting.
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
