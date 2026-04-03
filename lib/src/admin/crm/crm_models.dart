import "package:cloud_firestore/cloud_firestore.dart";

class CrmAssignment {
  const CrmAssignment({
    required this.investorUid,
    required this.assignedToUid,
    required this.assignedByUid,
    required this.assignedAt,
    this.updatedAt,
  });

  final String investorUid;
  final String assignedToUid;
  final String assignedByUid;
  final DateTime assignedAt;
  final DateTime? updatedAt;

  factory CrmAssignment.fromDoc(
    String investorUid,
    Map<String, dynamic> data,
  ) {
    return CrmAssignment(
      investorUid: investorUid,
      assignedToUid: (data["assignedToUid"] as String? ?? "").trim(),
      assignedByUid: (data["assignedByUid"] as String? ?? "").trim(),
      assignedAt: _ts(data["assignedAt"]) ?? DateTime.now(),
      updatedAt: _ts(data["updatedAt"]),
    );
  }

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return null;
  }
}

enum CrmNoteType { call, email, meeting, other }

class CrmNote {
  const CrmNote({
    required this.id,
    required this.investorUid,
    required this.authorUid,
    required this.body,
    required this.type,
    required this.createdAt,
    this.priority,
    this.followUpAt,
  });

  final String id;
  final String investorUid;
  final String authorUid;
  final String body;
  final CrmNoteType type;
  final DateTime createdAt;
  final String? priority;
  final DateTime? followUpAt;

  factory CrmNote.fromDoc(String id, Map<String, dynamic> data) {
    final t = (data["type"] as String? ?? "other").toLowerCase();
    final type = CrmNoteType.values.firstWhere(
      (e) => e.name == t,
      orElse: () => CrmNoteType.other,
    );
    return CrmNote(
      id: id,
      investorUid: (data["investorUid"] as String? ?? "").trim(),
      authorUid: (data["authorUid"] as String? ?? "").trim(),
      body: (data["body"] as String? ?? "").trim(),
      type: type,
      createdAt: _ts(data["createdAt"]) ?? DateTime.now(),
      priority: data["priority"] as String?,
      followUpAt: _ts(data["followUpAt"]),
    );
  }

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return null;
  }
}

enum CrmFollowupStatus { pending, completed, rescheduled }

class CrmFollowup {
  const CrmFollowup({
    required this.id,
    required this.investorUid,
    required this.ownerUid,
    required this.dueAt,
    required this.status,
    required this.title,
    required this.createdAt,
    this.completedAt,
    this.rescheduledTo,
  });

  final String id;
  final String investorUid;
  final String ownerUid;
  final DateTime dueAt;
  final CrmFollowupStatus status;
  final String title;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? rescheduledTo;

  factory CrmFollowup.fromDoc(String id, Map<String, dynamic> data) {
    final s = (data["status"] as String? ?? "pending").toLowerCase();
    final status = CrmFollowupStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => CrmFollowupStatus.pending,
    );
    return CrmFollowup(
      id: id,
      investorUid: (data["investorUid"] as String? ?? "").trim(),
      ownerUid: (data["ownerUid"] as String? ?? "").trim(),
      dueAt: _ts(data["dueAt"]) ?? DateTime.now(),
      status: status,
      title: (data["title"] as String? ?? "").trim(),
      createdAt: _ts(data["createdAt"]) ?? DateTime.now(),
      completedAt: _ts(data["completedAt"]),
      rescheduledTo: _ts(data["rescheduledTo"]),
    );
  }

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return null;
  }
}

enum CrmCommChannel { call, email, inPerson, other }

class CrmCommunication {
  const CrmCommunication({
    required this.id,
    required this.investorUid,
    required this.authorUid,
    required this.channel,
    required this.summary,
    required this.occurredAt,
    this.attachmentUrls = const [],
  });

  final String id;
  final String investorUid;
  final String authorUid;
  final CrmCommChannel channel;
  final String summary;
  final DateTime occurredAt;
  final List<String> attachmentUrls;

  factory CrmCommunication.fromDoc(String id, Map<String, dynamic> data) {
    final c = (data["channel"] as String? ?? "other").toLowerCase();
    final CrmCommChannel ch;
    switch (c) {
      case "call":
        ch = CrmCommChannel.call;
        break;
      case "email":
        ch = CrmCommChannel.email;
        break;
      case "in_person":
        ch = CrmCommChannel.inPerson;
        break;
      default:
        ch = CrmCommChannel.other;
    }
    final urls = (data["attachmentUrls"] as List?)?.map((e) => "$e").toList() ?? const <String>[];
    return CrmCommunication(
      id: id,
      investorUid: (data["investorUid"] as String? ?? "").trim(),
      authorUid: (data["authorUid"] as String? ?? "").trim(),
      channel: ch,
      summary: (data["summary"] as String? ?? "").trim(),
      occurredAt: _ts(data["occurredAt"]) ?? DateTime.now(),
      attachmentUrls: urls,
    );
  }

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return null;
  }
}
