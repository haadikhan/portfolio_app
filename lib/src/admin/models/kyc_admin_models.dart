import "package:cloud_firestore/cloud_firestore.dart";

/// Firestore `kyc/{userId}` document for admin review.
class KycAdminDocument {
  const KycAdminDocument({
    required this.userId,
    required this.status,
    required this.submittedAt,
    this.cnicFrontUrl,
    this.cnicBackUrl,
    this.selfieUrl,
    this.bankDetails,
    this.nominee,
    this.riskProfile,
    this.rejectionReason,
    this.reviewedAt,
    this.displayName,
    this.phone,
  });

  final String userId;
  final String status;
  final DateTime? submittedAt;
  final String? cnicFrontUrl;
  final String? cnicBackUrl;
  final String? selfieUrl;
  final Map<String, dynamic>? bankDetails;
  final Map<String, dynamic>? nominee;
  final Map<String, dynamic>? riskProfile;
  final String? rejectionReason;
  final DateTime? reviewedAt;

  /// Denormalized from `users/{userId}` when available.
  final String? displayName;
  final String? phone;

  factory KycAdminDocument.fromFirestore(
    String userId,
    Map<String, dynamic> data, {
    String? displayName,
    String? phone,
  }) {
    final submitted = data["submittedAt"];
    final reviewed = data["reviewedAt"];
    final identity = _asMap(data["identity"]);
    final images = _asMap(data["images"]);
    final docs = _asMap(data["documents"]);
    return KycAdminDocument(
      userId: userId,
      status: data["status"] as String? ?? "pending",
      submittedAt: _parseTime(submitted),
      cnicFrontUrl: _pickString(data, const [
            "cnicFrontUrl",
            "cnicFrontImageUrl",
            "cnicFrontDownloadUrl",
          ]) ??
          _pickString(identity, const [
            "cnicFrontUrl",
            "cnicFrontImageUrl",
            "frontUrl",
          ]) ??
          _pickString(images, const ["cnicFrontUrl", "frontUrl"]) ??
          _pickString(docs, const ["cnicFrontUrl", "frontUrl"]),
      cnicBackUrl: _pickString(data, const [
            "cnicBackUrl",
            "cnicBackImageUrl",
            "cnicBackDownloadUrl",
          ]) ??
          _pickString(identity, const [
            "cnicBackUrl",
            "cnicBackImageUrl",
            "backUrl",
          ]) ??
          _pickString(images, const ["cnicBackUrl", "backUrl"]) ??
          _pickString(docs, const ["cnicBackUrl", "backUrl"]),
      selfieUrl: _pickString(data, const [
            "selfieUrl",
            "selfieImageUrl",
            "selfieDownloadUrl",
            "faceUrl",
          ]) ??
          _pickString(identity, const [
            "selfieUrl",
            "selfieImageUrl",
            "faceUrl",
          ]) ??
          _pickString(images, const ["selfieUrl", "faceUrl"]) ??
          _pickString(docs, const ["selfieUrl", "faceUrl"]),
      bankDetails: data["bankDetails"] as Map<String, dynamic>?,
      nominee: data["nominee"] as Map<String, dynamic>?,
      riskProfile: data["riskProfile"] as Map<String, dynamic>?,
      rejectionReason: data["rejectionReason"] as String?,
      reviewedAt: _parseTime(reviewed),
      displayName: displayName,
      phone: phone,
    );
  }

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString());
  }

  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    return null;
  }

  static String? _pickString(
    Map<String, dynamic>? source,
    List<String> keys,
  ) {
    if (source == null) return null;
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}
