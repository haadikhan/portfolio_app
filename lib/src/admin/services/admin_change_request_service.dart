import "package:cloud_firestore/cloud_firestore.dart";

import "../../features/service_requests/models/change_request.dart";

/// Admin-side review service for investor service requests (`changeRequests`).
///
/// Firestore indexes (create in console if prompted):
/// - Collection group **`changeRequests`**: **`status`** (Ascending), **`requestedAt`** (Descending)
///
/// Same collection group ordering by **`requestedAt`** descending only may be sufficient for "All".
///
/// Rules: **`changeRequests`** may need explicit security rules allowing investors to **create**
/// docs with `status == "pending"` and admins with backend/Admin SDK to update (not covered here).
class AdminChangeRequestService {
  AdminChangeRequestService(this._db);

  final FirebaseFirestore _db;

  Stream<List<ChangeRequest>> watchPendingAcrossInvestors() {
    return _db
        .collectionGroup("changeRequests")
        .where("status", isEqualTo: ChangeRequest.kPending)
        .orderBy("requestedAt", descending: true)
        .snapshots()
        .map(
          (s) =>
              s.docs.map((d) => ChangeRequest.fromDoc(d)).toList(growable: false),
        );
  }

  Stream<List<ChangeRequest>> watchAllAcrossInvestors() {
    return _db
        .collectionGroup("changeRequests")
        .orderBy("requestedAt", descending: true)
        .limit(250)
        .snapshots()
        .map(
          (s) =>
              s.docs.map((d) => ChangeRequest.fromDoc(d)).toList(growable: false),
        );
  }

  Stream<List<ChangeRequest>> watchForInvestor(String uid) {
    return _db
        .collection("users")
        .doc(uid)
        .collection("changeRequests")
        .orderBy("requestedAt", descending: true)
        .snapshots()
        .map(
          (s) =>
              s.docs.map((d) => ChangeRequest.fromDoc(d)).toList(growable: false),
        );
  }

  Future<void> approve({
    required ChangeRequest request,
    required String adminUid,
    String? note,
  }) async {
    final investorUid = request.uid;
    final userRef = _db.collection("users").doc(investorUid);
    final ticketRef = userRef
        .collection("changeRequests")
        .doc(request.ticketId);

    final batch = _db.batch();

    batch.set(userRef, request.requestedFields, SetOptions(merge: true));

    batch.update(ticketRef, <String, dynamic>{
      "status": ChangeRequest.kApproved,
      "reviewedAt": FieldValue.serverTimestamp(),
      "reviewedBy": adminUid,
      "reviewNote":
          note == null || note.trim().isEmpty ? null : note.trim(),
    });

    await batch.commit();

    final typeLabel =
        _friendlyTypeLabel(request.requestType); // localized on client inbox as English fallback
    await _writeNotification(
      uid: investorUid,
      title: "Change request approved",
      body: "Your request ($typeLabel) was approved.${note != null && note.trim().isNotEmpty ? " Note: ${note.trim()}" : ""}",
      ticketId: request.ticketId,
    );
  }

  Future<void> reject({
    required ChangeRequest request,
    required String adminUid,
    String? note,
  }) async {
    final investorUid = request.uid;
    final ticketRef = _db
        .collection("users")
        .doc(investorUid)
        .collection("changeRequests")
        .doc(request.ticketId);

    await ticketRef.update(<String, dynamic>{
      "status": ChangeRequest.kRejected,
      "reviewedAt": FieldValue.serverTimestamp(),
      "reviewedBy": adminUid,
      "reviewNote": note == null || note.trim().isEmpty ? null : note.trim(),
    });

    final typeLabel = _friendlyTypeLabel(request.requestType);
    await _writeNotification(
      uid: investorUid,
      title: "Change request rejected",
      body:
          "Your request ($typeLabel) was rejected.${note != null && note.trim().isNotEmpty ? " Reason: ${note.trim()}" : ""}",
      ticketId: request.ticketId,
    );
  }

  String _friendlyTypeLabel(String type) {
    switch (type.toLowerCase().trim()) {
      case "profile":
        return "profile";
      case "phone":
        return "phone number";
      case "bank":
        return "bank details";
      case "nominee":
        return "nominee details";
      default:
        return type;
    }
  }

  /// In-app inbox row — matches fields read by `NotificationsScreen` (`title`, `body`,
  /// `read`, `createdAt`, optional `action` / `refId`).
  Future<void> _writeNotification({
    required String uid,
    required String title,
    required String body,
    required String ticketId,
  }) async {
    await _db.collection("users").doc(uid).collection("notifications").add({
      "title": title,
      "body": body,
      "type": "service_request",
      "read": false,
      "createdAt": FieldValue.serverTimestamp(),
      "action": "none",
      "refId": ticketId,
    });
  }
}
