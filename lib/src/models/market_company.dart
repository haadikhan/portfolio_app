import "package:cloud_firestore/cloud_firestore.dart";

class MarketCompany {
  const MarketCompany({
    required this.id,
    required this.name,
    required this.ticker,
    required this.exchange,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  final String id;
  final String name;
  final String ticker;
  final String exchange;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  factory MarketCompany.fromMap(String id, Map<String, dynamic> map) {
    return MarketCompany(
      id: id,
      name: (map["name"] as String? ?? "").trim(),
      ticker: (map["ticker"] as String? ?? "").trim().toUpperCase(),
      exchange: (map["exchange"] as String? ?? "").trim().toUpperCase(),
      isActive: map["isActive"] == true,
      createdAt: _parseTs(map["createdAt"]),
      updatedAt: _parseTs(map["updatedAt"]),
      createdBy: (map["createdBy"] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toMap() => {
    "name": name.trim(),
    "ticker": ticker.trim().toUpperCase(),
    "exchange": exchange.trim().toUpperCase(),
    "isActive": isActive,
    if (createdAt != null) "createdAt": Timestamp.fromDate(createdAt!),
    if (updatedAt != null) "updatedAt": Timestamp.fromDate(updatedAt!),
    if (createdBy != null && createdBy!.isNotEmpty) "createdBy": createdBy,
  };

  static DateTime? _parseTs(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
