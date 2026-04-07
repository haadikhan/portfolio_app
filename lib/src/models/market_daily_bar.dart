import "package:cloud_firestore/cloud_firestore.dart";

class MarketDailyBar {
  const MarketDailyBar({
    required this.id,
    required this.date,
    required this.open,
    required this.close,
    this.high,
    this.low,
    this.volume,
    this.source = "manual",
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final DateTime date;
  final double open;
  final double close;
  final double? high;
  final double? low;
  final double? volume;
  final String source;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory MarketDailyBar.fromMap(String id, Map<String, dynamic> map) {
    return MarketDailyBar(
      id: id,
      date: _parseTs(map["date"]) ?? DateTime.now(),
      open: (map["open"] as num?)?.toDouble() ?? 0,
      close: (map["close"] as num?)?.toDouble() ?? 0,
      high: (map["high"] as num?)?.toDouble(),
      low: (map["low"] as num?)?.toDouble(),
      volume: (map["volume"] as num?)?.toDouble(),
      source: (map["source"] as String? ?? "manual").trim(),
      updatedAt: _parseTs(map["updatedAt"]),
      updatedBy: (map["updatedBy"] as String?)?.trim(),
    );
  }

  static DateTime? _parseTs(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
