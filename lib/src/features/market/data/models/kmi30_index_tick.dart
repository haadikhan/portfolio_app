import "package:portfolio_app/src/features/market/data/models/kmi30_tick.dart";

/// Live KMI30 **index** data from PSX REST (distinct from [Kmi30Tick] per-company ticks).
class Kmi30IndexTick {
  const Kmi30IndexTick({
    required this.currentValue,
    required this.changeAbsolute,
    required this.changePercent,
    this.high,
    this.low,
    this.volume,
    required this.receivedAt,
  });

  final double currentValue;
  final double changeAbsolute;
  final double changePercent;
  final double? high;
  final double? low;
  final double? volume;
  final DateTime receivedAt;

  /// Parse from psxterminal REST tick response for IDX/KMI30.
  factory Kmi30IndexTick.fromRestJson(Map<String, dynamic> json) {
    double d(dynamic v) =>
        v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;

    final data = (json["data"] as Map?)?.cast<String, dynamic>() ?? json;

    final close = d(data["close"] ?? data["last"] ?? data["price"]);
    final open = d(data["open"]);
    var chgAbs = d(data["change"] ?? data["changeAbsolute"]);
    var chgPct = d(
      data["changePercent"] ?? data["changePct"] ?? data["pct"],
    );
    chgPct = displayKmi30Percent(chgPct);

    if (chgAbs == 0 && open != 0 && close != 0) {
      chgAbs = close - open;
    }

    return Kmi30IndexTick(
      currentValue: close,
      changeAbsolute: chgAbs,
      changePercent: chgPct,
      high: data["high"] != null ? d(data["high"]) : null,
      low: data["low"] != null ? d(data["low"]) : null,
      volume: data["volume"] != null ? d(data["volume"]) : null,
      receivedAt: DateTime.now(),
    );
  }

  Kmi30IndexTick copyWith({double? changePercent}) => Kmi30IndexTick(
        currentValue: currentValue,
        changeAbsolute: changeAbsolute,
        changePercent: changePercent ?? this.changePercent,
        high: high,
        low: low,
        volume: volume,
        receivedAt: receivedAt,
      );
}
