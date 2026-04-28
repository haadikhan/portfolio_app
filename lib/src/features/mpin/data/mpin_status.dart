import "package:cloud_firestore/cloud_firestore.dart";

/// Public, client-readable view of the MPIN feature flags from `users/{uid}`.
/// Hash + salt are intentionally excluded — they live on the server only.
class MpinStatus {
  const MpinStatus({
    required this.hasMpin,
    required this.enabled,
    this.lockedUntil,
  });

  final bool hasMpin;
  final bool enabled;
  final DateTime? lockedUntil;

  static const empty = MpinStatus(hasMpin: false, enabled: false);

  bool get isLockedNow {
    final t = lockedUntil;
    return t != null && t.isAfter(DateTime.now());
  }

  /// Build from a Firestore `users/{uid}` document map. Tolerates missing
  /// fields (legacy users) — returns the default "no MPIN" state.
  static MpinStatus fromUserDoc(Map<String, dynamic>? data) {
    if (data == null) return empty;
    final hasHash = (data["mpinHash"] as String?)?.isNotEmpty ?? false;
    final hasSalt = (data["mpinSalt"] as String?)?.isNotEmpty ?? false;
    final hasMpin = hasHash && hasSalt;
    final enabled = hasMpin && (data["mpinEnabled"] == true);
    final lockedRaw = data["mpinLockedUntil"];
    DateTime? lockedUntil;
    if (lockedRaw is Timestamp) {
      lockedUntil = lockedRaw.toDate();
    } else if (lockedRaw is DateTime) {
      lockedUntil = lockedRaw;
    } else if (lockedRaw is int) {
      lockedUntil = DateTime.fromMillisecondsSinceEpoch(lockedRaw);
    }
    if (lockedUntil != null && !lockedUntil.isAfter(DateTime.now())) {
      lockedUntil = null;
    }
    return MpinStatus(
      hasMpin: hasMpin,
      enabled: enabled,
      lockedUntil: lockedUntil,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! MpinStatus) return false;
    return other.hasMpin == hasMpin &&
        other.enabled == enabled &&
        other.lockedUntil == lockedUntil;
  }

  @override
  int get hashCode => Object.hash(hasMpin, enabled, lockedUntil);
}
