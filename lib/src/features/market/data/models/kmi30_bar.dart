class Kmi30Bar {
  const Kmi30Bar({
    required this.symbol,
    required this.timeframe,
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  final String symbol;
  final String timeframe;
  final DateTime timestamp;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  factory Kmi30Bar.fromJson(Map<String, dynamic> json) {
    return Kmi30Bar(
      symbol: (json["symbol"] as String? ?? "").trim(),
      timeframe: (json["timeframe"] as String? ?? "").trim(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json["timestamp"] as num?)?.toInt() ?? 0,
      ),
      open: (json["open"] as num?)?.toDouble() ?? 0,
      high: (json["high"] as num?)?.toDouble() ?? 0,
      low: (json["low"] as num?)?.toDouble() ?? 0,
      close: (json["close"] as num?)?.toDouble() ?? 0,
      volume: (json["volume"] as num?)?.toDouble() ?? 0,
    );
  }
}
