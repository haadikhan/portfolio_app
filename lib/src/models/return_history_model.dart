import "package:cloud_firestore/cloud_firestore.dart";

class ReturnHistoryModel {
  const ReturnHistoryModel({
    required this.id,
    required this.returnPct,
    required this.profitAmount,
    required this.previousValue,
    required this.newValue,
    required this.appliedAt,
    required this.appliedBy,
    required this.mode,
  });

  final String id;
  final double returnPct;
  final double profitAmount;
  final double previousValue;
  final double newValue;
  final DateTime appliedAt;
  final String appliedBy;

  /// "percentage" or "manual"
  final String mode;

  factory ReturnHistoryModel.fromMap(String id, Map<String, dynamic> map) {
    return ReturnHistoryModel(
      id: id,
      returnPct: (map["returnPct"] as num?)?.toDouble() ?? 0,
      profitAmount: (map["profitAmount"] as num?)?.toDouble() ?? 0,
      previousValue: (map["previousValue"] as num?)?.toDouble() ?? 0,
      newValue: (map["newValue"] as num?)?.toDouble() ?? 0,
      appliedAt: _parseTime(map["appliedAt"]) ?? DateTime.now(),
      appliedBy: (map["appliedBy"] as String?) ?? "",
      mode: (map["mode"] as String?) ?? "percentage",
    );
  }

  Map<String, dynamic> toMap() => {
        "returnPct": returnPct,
        "profitAmount": profitAmount,
        "previousValue": previousValue,
        "newValue": newValue,
        "appliedAt": Timestamp.fromDate(appliedAt),
        "appliedBy": appliedBy,
        "mode": mode,
      };

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString());
  }
}
