import "package:cloud_firestore/cloud_firestore.dart";

class PortfolioModel {
  const PortfolioModel({
    required this.uid,
    required this.currentValue,
    required this.totalDeposited,
    required this.lastMonthlyReturnPct,
    required this.lastUpdated,
    required this.createdAt,
  });

  final String uid;
  final double currentValue;
  final double totalDeposited;
  final double lastMonthlyReturnPct;
  final DateTime lastUpdated;
  final DateTime createdAt;

  double get totalReturnPct =>
      totalDeposited <= 0 ? 0 : ((currentValue - totalDeposited) / totalDeposited) * 100;

  double get netGain => currentValue - totalDeposited;

  factory PortfolioModel.fromMap(String uid, Map<String, dynamic> map) {
    return PortfolioModel(
      uid: uid,
      currentValue: (map["currentValue"] as num?)?.toDouble() ?? 0,
      totalDeposited: (map["totalDeposited"] as num?)?.toDouble() ?? 0,
      lastMonthlyReturnPct: (map["lastMonthlyReturnPct"] as num?)?.toDouble() ?? 0,
      lastUpdated: _parseTime(map["lastUpdated"]) ?? DateTime.now(),
      createdAt: _parseTime(map["createdAt"]) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        "currentValue": currentValue,
        "totalDeposited": totalDeposited,
        "lastMonthlyReturnPct": lastMonthlyReturnPct,
        "lastUpdated": Timestamp.fromDate(lastUpdated),
        "createdAt": Timestamp.fromDate(createdAt),
      };

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString());
  }
}
