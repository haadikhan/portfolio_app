import "package:cloud_firestore/cloud_firestore.dart";

import "app_user.dart";

class UserKycRecord {
  const UserKycRecord({
    required this.userId,
    required this.status,
    this.cnicNumber,
    this.phone,
    this.cnicFrontUrl,
    this.cnicBackUrl,
    this.selfieUrl,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
  });

  final String userId;
  final KycLifecycleStatus status;
  final String? cnicNumber;
  final String? phone;
  final String? cnicFrontUrl;
  final String? cnicBackUrl;
  final String? selfieUrl;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  bool get isLocked => status == KycLifecycleStatus.underReview;
  bool get isApproved => status == KycLifecycleStatus.approved;
  bool get canResubmit =>
      status == KycLifecycleStatus.rejected || status == KycLifecycleStatus.pending;

  factory UserKycRecord.fromMap(String userId, Map<String, dynamic> map) {
    final rawStatus = (map["status"] as String? ?? "pending").toLowerCase();
    final status = KycLifecycleStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == rawStatus,
      orElse: () => KycLifecycleStatus.pending,
    );
    return UserKycRecord(
      userId: userId,
      status: status,
      cnicNumber: (map["cnicNumber"] as String?)?.trim(),
      phone: (map["phone"] as String?)?.trim(),
      cnicFrontUrl: (map["cnicFrontUrl"] as String?)?.trim(),
      cnicBackUrl: (map["cnicBackUrl"] as String?)?.trim(),
      selfieUrl: (map["selfieUrl"] as String?)?.trim(),
      rejectionReason: (map["rejectionReason"] as String?)?.trim(),
      submittedAt: _parseTime(map["submittedAt"]),
      reviewedAt: _parseTime(map["reviewedAt"]),
    );
  }

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString());
  }
}
