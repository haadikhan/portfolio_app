class GoldPriceQuote {
  const GoldPriceQuote({
    required this.xauUsd,
    required this.usdPkr,
    required this.xauPkr,
    required this.timestamp,
    required this.source,
    /// Prior session close in PKR per troy oz when available (e.g. Binance 1d).
    this.previousClosePkr,
  });

  final double xauUsd;
  final double usdPkr;
  final double xauPkr;
  final DateTime timestamp;
  final String source;
  final double? previousClosePkr;

  /// Day-over-day % vs [previousClosePkr]; **0** when prior close unknown.
  double get changePercent {
    final prev = previousClosePkr;
    if (prev == null || prev <= 0) {
      return 0.0;
    }
    return ((xauPkr - prev) / prev) * 100;
  }
}
