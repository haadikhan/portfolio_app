class Kmi30Tick {
  const Kmi30Tick({
    required this.symbol,
    required this.price,
    required this.change,
    required this.changePercent,
    this.open,
    required this.high,
    required this.low,
    required this.volume,
    required this.timestamp,
  });

  final String symbol;
  final double price;
  final double change;
  final double changePercent;
  /// Session/day open when provided by API (REST or WS).
  final double? open;
  final double high;
  final double low;
  final double volume;
  final DateTime timestamp;

  Kmi30Tick copyWith({
    String? symbol,
    double? price,
    double? change,
    double? changePercent,
    double? open,
    double? high,
    double? low,
    double? volume,
    DateTime? timestamp,
  }) {
    return Kmi30Tick(
      symbol: symbol ?? this.symbol,
      price: price ?? this.price,
      change: change ?? this.change,
      changePercent: changePercent ?? this.changePercent,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      volume: volume ?? this.volume,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  factory Kmi30Tick.fromRestJson(Map<String, dynamic> json) {
    final data = (json["data"] as Map?)?.cast<String, dynamic>() ?? json;
    return Kmi30Tick(
      symbol: (data["symbol"] as String? ?? "").trim().toUpperCase(),
      price: (data["price"] as num?)?.toDouble() ?? 0,
      change: (data["change"] as num?)?.toDouble() ?? 0,
      changePercent: (data["changePercent"] as num?)?.toDouble() ?? 0,
      open: (data["open"] as num?)?.toDouble(),
      high: (data["high"] as num?)?.toDouble() ?? 0,
      low: (data["low"] as num?)?.toDouble() ?? 0,
      volume: (data["volume"] as num?)?.toDouble() ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        ((data["timestamp"] as num?)?.toInt() ?? 0) * 1000,
      ),
    );
  }

  factory Kmi30Tick.fromWsJson(Map<String, dynamic> json) {
    final symbol = _parseSymbol(
      json["symbol"] ?? json["s"] ?? (json["params"] as Map?)?["symbol"],
    );
    final openRaw = json["open"] ?? json["o"];
    return Kmi30Tick(
      symbol: symbol,
      price: ((json["price"] ?? json["c"]) as num?)?.toDouble() ?? 0,
      change: ((json["change"] ?? json["ch"]) as num?)?.toDouble() ?? 0,
      changePercent:
          ((json["changePercent"] ?? json["pch"]) as num?)?.toDouble() ?? 0,
      open: (openRaw is num) ? openRaw.toDouble() : null,
      high: ((json["high"] ?? json["h"]) as num?)?.toDouble() ?? 0,
      low: ((json["low"] ?? json["l"]) as num?)?.toDouble() ?? 0,
      volume: ((json["volume"] ?? json["v"]) as num?)?.toDouble() ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        _parseTimestampMs(json["timestamp"] ?? json["t"]),
      ),
    );
  }

  static String _parseSymbol(dynamic raw) {
    if (raw == null) return "";
    if (raw is String) return raw.trim().toUpperCase();
    return raw.toString().trim().toUpperCase();
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

/// PSX may send changePercent as a fraction (e.g. 0.019) or as whole percent.
double displayKmi30Percent(double raw) {
  if (raw == 0) return 0;
  if (raw.abs() < 1) return raw * 100;
  return raw;
}
