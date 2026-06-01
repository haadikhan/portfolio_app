class Kmi30Company {
  const Kmi30Company({
    required this.symbol,
    required this.name,
    required this.weightPercent,
  });

  final String symbol;
  final String name;

  /// Approximate free-float market cap weight in KMI30.
  /// Source: PSX official composition (May 2026).
  /// Cap: 12% per constituent per PSX methodology.
  /// Sum of all weights = 100.0
  /// Update semi-annually when PSX recomposes KMI30.
  final double weightPercent;
}
