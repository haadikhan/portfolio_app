enum KycLifecycleStatus { pending, underReview, approved, rejected }

/// Stored WAI-ISCMA-XXXXXX portfolio number, or UID-tail fallback before backfill.
String resolvePortfolioNumber(String? stored, String uid) {
  if (stored != null && stored.isNotEmpty) return stored;
  final t = uid.trim();
  return t.length >= 8
      ? t.substring(t.length - 8).toUpperCase()
      : t.toUpperCase();
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
    this.kycStatus = KycLifecycleStatus.pending,
    this.role,
    this.portfolioNumber,
  });

  final String id;
  final String email;
  final String name;
  final DateTime createdAt;

  /// Synced from Firestore `users/{id}.kycStatus` (set by KYC submit / admin review).
  final KycLifecycleStatus kycStatus;

  /// Firestore `users/{id}.role` — e.g. `admin` for staff tools.
  final String? role;

  /// Firestore `users/{id}.portfolioNumber` — e.g. WAI-ISCMA-000001.
  final String? portfolioNumber;

  bool get isAdmin => (role ?? "").toLowerCase() == "admin";

  Map<String, dynamic> toMap() {
    return {
      "email": email,
      "name": name,
      "createdAt": createdAt.toIso8601String(),
      "kycStatus": kycStatus.name,
      if (role != null) "role": role,
      if (portfolioNumber != null) "portfolioNumber": portfolioNumber,
    };
  }

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    final created = map["createdAt"];
    final kycRaw = (map["kycStatus"] as String? ?? "pending").toLowerCase();
    final kyc = KycLifecycleStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == kycRaw,
      orElse: () => KycLifecycleStatus.pending,
    );
    return AppUser(
      id: id,
      email: map["email"] as String? ?? "",
      name: map["name"] as String? ?? "",
      createdAt: DateTime.tryParse(created?.toString() ?? "") ?? DateTime.now(),
      kycStatus: kyc,
      role: map["role"] as String?,
      portfolioNumber: (map["portfolioNumber"] as String?)?.trim(),
    );
  }
}
