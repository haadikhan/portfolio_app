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
    // Nested maps may exist as `{}` from older clients; still merge flat fields.
    final bankDetailsMap = _mergeBankDetails(data);
    final nomineeMap = _mergeNominee(data);
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
      bankDetails: bankDetailsMap.isEmpty ? null : bankDetailsMap,
      nominee: nomineeMap.isEmpty ? null : nomineeMap,
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
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val));
    }
    return null;
  }

  /// Bank: nested `bankDetails` plus flat `bankName` / IBAN fields from mobile KYC.
  static Map<String, dynamic> _mergeBankDetails(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    final nested = _asMap(data["bankDetails"]);
    if (nested != null) {
      for (final e in nested.entries) {
        if (e.value != null) out[e.key] = e.value;
      }
    }
    void putIfEmpty(String key, String? value) {
      if (value == null || value.isEmpty) return;
      final cur = out[key];
      if (cur == null) {
        out[key] = value;
        return;
      }
      if (cur is String && cur.trim().isEmpty) {
        out[key] = value;
      }
    }

    putIfEmpty("bankName", _readLooseString(data, "bankName"));
    putIfEmpty("accountTitle", _readLooseString(data, "accountTitle"));
    final iban = _readLooseString(data, "ibanOrAccountNumber") ??
        _readLooseString(data, "accountNumber");
    putIfEmpty("ibanOrAccountNumber", iban);
    return out;
  }

  /// Nominee: nested `nominee` plus flat nominee fields from mobile KYC.
  static Map<String, dynamic> _mergeNominee(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    final nested = _asMap(data["nominee"]);
    if (nested != null) {
      for (final e in nested.entries) {
        if (e.value != null) out[e.key] = e.value;
      }
    }
    void putIfEmpty(String key, String? value) {
      if (value == null || value.isEmpty) return;
      final cur = out[key];
      if (cur == null) {
        out[key] = value;
        return;
      }
      if (cur is String && cur.trim().isEmpty) {
        out[key] = value;
      }
    }

    putIfEmpty("nomineeName", _readLooseString(data, "nomineeName"));
    putIfEmpty(
      "relationship",
      _readLooseString(data, "nomineeRelation") ??
          _readLooseString(data, "relationship"),
    );
    putIfEmpty("nomineeCnic", _readLooseString(data, "nomineeCnic"));
    return out;
  }

  static String? _readLooseString(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value == null) return null;
    if (value is String) {
      final t = value.trim();
      return t.isEmpty ? null : t;
    }
    final t = value.toString().trim();
    if (t.isEmpty || t == "null") return null;
    return t;
  }

  static String? _pickString(
    Map<String, dynamic>? source,
    List<String> keys,
  ) {
    if (source == null) return null;
    for (final key in keys) {
      final s = _readLooseString(source, key);
      if (s != null) return s;
    }
    return null;
  }
}
