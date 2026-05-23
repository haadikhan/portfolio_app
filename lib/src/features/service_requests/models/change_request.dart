import "package:cloud_firestore/cloud_firestore.dart";

/// Service request ticket under `users/{uid}/changeRequests/{ticketId}`.
class ChangeRequest {
  const ChangeRequest({
    required this.ticketId,
    required this.uid,
    required this.requestType,
    required this.requestedFields,
    required this.currentFields,
    required this.status,
    required this.requestedAt,
    this.reviewedAt,
    this.reviewNote,
    this.reviewedBy,
    this.investorName,
    this.investorEmail,
  });

  static const String kPending = "pending";
  static const String kApproved = "approved";
  static const String kRejected = "rejected";

  final String ticketId;
  final String uid;
  final String requestType;
  final Map<String, dynamic> requestedFields;
  final Map<String, dynamic> currentFields;
  final String status;
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final String? reviewNote;
  final String? reviewedBy;
  final String? investorName;
  final String? investorEmail;

  bool get isPending => status == kPending;
  bool get isApproved => status == kApproved;
  bool get isRejected => status == kRejected;

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString());
  }

  factory ChangeRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final parent = doc.reference.parent.parent;
    if (parent == null) {
      throw ArgumentError(
        "changeRequests doc missing parent uid: ${doc.reference.path}",
      );
    }
    final d = doc.data() ?? {};
    final requested = Map<String, dynamic>.from(
      (d["requestedFields"] as Map?)?.cast<String, dynamic>() ?? {},
    );
    final current = Map<String, dynamic>.from(
      (d["currentFields"] as Map?)?.cast<String, dynamic>() ?? {},
    );
    return ChangeRequest(
      ticketId: doc.id,
      uid: parent.id,
      requestType: (d["requestType"] as String? ?? "").trim(),
      requestedFields: requested,
      currentFields: current,
      status: (d["status"] as String? ?? kPending).toLowerCase(),
      requestedAt: _parseTime(d["requestedAt"]) ?? DateTime.fromMillisecondsSinceEpoch(0),
      reviewedAt: _parseTime(d["reviewedAt"]),
      reviewNote: (d["reviewNote"] as String?)?.trim(),
      reviewedBy: (d["reviewedBy"] as String?)?.trim(),
      investorName: _readOptionalString(d["investorName"]),
      investorEmail: _readOptionalString(d["investorEmail"]),
    );
  }

  static String? _readOptionalString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Payload for Firestore `.add(...)` — no ticketId / review fields.
  static Map<String, dynamic> createNewDocPayload({
    required String requestType,
    required Map<String, dynamic> requestedFields,
    required Map<String, dynamic> currentFields,
    String? investorName,
    String? investorEmail,
  }) {
    return <String, dynamic>{
      "requestType": requestType,
      "requestedFields": requestedFields,
      "currentFields": currentFields,
      "status": kPending,
      "requestedAt": FieldValue.serverTimestamp(),
      "reviewedAt": null,
      "reviewNote": null,
      "reviewedBy": null,
      if (investorName != null && investorName.isNotEmpty)
        "investorName": investorName,
      if (investorEmail != null && investorEmail.isNotEmpty)
        "investorEmail": investorEmail,
    };
  }
}

bool hasPendingForType(List<ChangeRequest> requests, String requestType) {
  final t = requestType.trim().toLowerCase();
  return requests.any(
    (r) => r.isPending && r.requestType.toLowerCase() == t,
  );
}
