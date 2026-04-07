class Kmi30Tick {
  const Kmi30Tick({
    required this.symbol,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.high,
    required this.low,
    required this.volume,
    required this.timestamp,
  });

  final String symbol;
  final double price;
  final double change;
  final double changePercent;
  final double high;
  final double low;
  final double volume;
  final DateTime timestamp;

  factory Kmi30Tick.fromRestJson(Map<String, dynamic> json) {
    final data = (json["data"] as Map?)?.cast<String, dynamic>() ?? json;
    return Kmi30Tick(
      symbol: (data["symbol"] as String? ?? "").trim().toUpperCase(),
      price: (data["price"] as num?)?.toDouble() ?? 0,
      change: (data["change"] as num?)?.toDouble() ?? 0,
      changePercent: (data["changePercent"] as num?)?.toDouble() ?? 0,
      high: (data["high"] as num?)?.toDouble() ?? 0,
      low: (data["low"] as num?)?.toDouble() ?? 0,
      volume: (data["volume"] as num?)?.toDouble() ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        ((data["timestamp"] as num?)?.toInt() ?? 0) * 1000,
      ),
    );
  }

  factory Kmi30Tick.fromWsJson(Map<String, dynamic> json) {
    final symbol = (json["symbol"] ??
            json["s"] ??
            (json["params"] as Map?)?["symbol"] ??
            "") as String;
    return Kmi30Tick(
      symbol: symbol.trim().toUpperCase(),
      price: ((json["price"] ?? json["c"]) as num?)?.toDouble() ?? 0,
      change: ((json["change"] ?? json["ch"]) as num?)?.toDouble() ?? 0,
      changePercent:
          ((json["changePercent"] ?? json["pch"]) as num?)?.toDouble() ?? 0,
      high: ((json["high"] ?? json["h"]) as num?)?.toDouble() ?? 0,
      low: ((json["low"] ?? json["l"]) as num?)?.toDouble() ?? 0,
      volume: ((json["volume"] ?? json["v"]) as num?)?.toDouble() ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        _parseTimestampMs(json["timestamp"] ?? json["t"]),
      ),
    );
  }

  static int _parseTimestampMs(dynamic raw) {
    if (raw is num) {
      final v = raw.toInt();
      if (v > 1000000000000) return v; // already ms
      return v * 1000; // seconds -> ms
    }
    return DateTime.now().millisecondsSinceEpoch;
  }
}
