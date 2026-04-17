class GoldPriceQuote {
  const GoldPriceQuote({
    required this.xauUsd,
    required this.usdPkr,
    required this.xauPkr,
    required this.timestamp,
    required this.source,
  });

  final double xauUsd;
  final double usdPkr;
  final double xauPkr;
  final DateTime timestamp;
  final String source;
}
