import "package:cloud_firestore/cloud_firestore.dart";

import "../models/admin_investor_models.dart";
import "../services/admin_investor_service.dart";
import "crm_models.dart";

class CrmService {
  CrmService(this._db, this._investorService);

  final FirebaseFirestore _db;
  final AdminInvestorService _investorService;

  CollectionReference<Map<String, dynamic>> get _assignments =>
      _db.collection("crm_assignments");
  CollectionReference<Map<String, dynamic>> get _notes =>
      _db.collection("crm_notes");
  CollectionReference<Map<String, dynamic>> get _followups =>
      _db.collection("crm_followups");
  CollectionReference<Map<String, dynamic>> get _comms =>
      _db.collection("crm_communications");

  Future<CrmAssignment?> getAssignment(String investorUid) async {
    final doc = await _assignments.doc(investorUid).get();
    if (!doc.exists || doc.data() == null) return null;
    return CrmAssignment.fromDoc(doc.id, doc.data()!);
  }

  Future<void> setAssignment({
    required String investorUid,
    required String assignedToUid,
    required String assignedByUid,
  }) async {
    final now = FieldValue.serverTimestamp();
    await _assignments.doc(investorUid).set({
      "assignedToUid": assignedToUid,
      "assignedByUid": assignedByUid,
      "assignedAt": now,
      "updatedAt": now,
    }, SetOptions(merge: true));
  }

  Future<void> clearAssignment(String investorUid) async {
    await _assignments.doc(investorUid).delete();
  }

  /// CRM member: assigned investors only. Admin: all investors (same as fetchInvestors) with optional assignment map.
  Future<List<AdminInvestorSummary>> fetchInvestorsForCrm({
    required String crmUid,
    required bool isAdmin,
  }) async {
    if (isAdmin) {
      return _investorService.fetchInvestors();
    }
    final q = await _assignments
        .where("assignedToUid", isEqualTo: crmUid)
        .get();
    final out = <AdminInvestorSummary>[];
    for (final doc in q.docs) {
      final uid = doc.id;
      final detail = await _investorService.fetchInvestorDetail(uid);
      if (detail != null) {
        out.add(detail.summary);
      } else {
        out.add(
          AdminInvestorSummary(
            userId: uid,
            name: "",
            email: "",
            phone: "",
            kycStatus: "pending",
            createdAt: null,
            role: "investor",
          ),
        );
      }
    }
    out.sort((a, b) {
      final an = a.name.isEmpty ? a.email : a.name;
      final bn = b.name.isEmpty ? b.email : b.name;
      return an.toLowerCase().compareTo(bn.toLowerCase());
    });
    return out;
  }

  Stream<List<CrmNote>> watchNotes(String investorUid) {
    return _notes
        .where("investorUid", isEqualTo: investorUid)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => CrmNote.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> addNote({
    required String investorUid,
    required String authorUid,
    required String body,
    required CrmNoteType type,
    String? priority,
    DateTime? followUpAt,
  }) async {
    await _notes.add({
      "investorUid": investorUid,
      "authorUid": authorUid,
      "body": body,
      "type": type.name,
      "createdAt": FieldValue.serverTimestamp(),
      if (priority != null && priority.isNotEmpty) "priority": priority,
      if (followUpAt != null) "followUpAt": Timestamp.fromDate(followUpAt),
    });
  }

  Stream<List<CrmFollowup>> watchFollowups(String investorUid) {
    return _followups
        .where("investorUid", isEqualTo: investorUid)
        .orderBy("dueAt", descending: false)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => CrmFollowup.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> addFollowup({
    required String investorUid,
    required String ownerUid,
    required DateTime dueAt,
    required String title,
  }) async {
    await _followups.add({
      "investorUid": investorUid,
      "ownerUid": ownerUid,
      "dueAt": Timestamp.fromDate(dueAt),
      "status": CrmFollowupStatus.pending.name,
      "title": title,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateFollowupStatus({
    required String followupId,
    required CrmFollowupStatus status,
    DateTime? rescheduledTo,
  }) async {
    final data = <String, dynamic>{
      "status": status.name,
    };
    if (status == CrmFollowupStatus.completed) {
      data["completedAt"] = FieldValue.serverTimestamp();
    }
    if (rescheduledTo != null) {
      data["rescheduledTo"] = Timestamp.fromDate(rescheduledTo);
    }
    await _followups.doc(followupId).update(data);
  }

  Stream<List<CrmCommunication>> watchCommunications(String investorUid) {
    return _comms
        .where("investorUid", isEqualTo: investorUid)
        .orderBy("occurredAt", descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => CrmCommunication.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> addCommunication({
    required String investorUid,
    required String authorUid,
    required CrmCommChannel channel,
    required String summary,
    required DateTime occurredAt,
    List<String> attachmentUrls = const [],
  }) async {
    await _comms.add({
      "investorUid": investorUid,
      "authorUid": authorUid,
      "channel": channel == CrmCommChannel.inPerson ? "in_person" : channel.name,
      "summary": summary,
      "occurredAt": Timestamp.fromDate(occurredAt),
      "attachmentUrls": attachmentUrls,
    });
  }

  Future<int> countPendingFollowupsForCrm(String crmUid) async {
    final q = await _followups
        .where("ownerUid", isEqualTo: crmUid)
        .where("status", isEqualTo: "pending")
        .get();
    return q.docs.length;
  }
}
