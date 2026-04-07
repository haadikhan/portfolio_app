/// Illustrative month-end values (PKR) for the founder reference portfolio.
/// Update these values when you publish a new static snapshot (app release).
class FounderPerformancePoint {
  FounderPerformancePoint(this.month, this.valuePkr);

  final DateTime month;
  final double valuePkr;
}

/// Ascending by month. Values are illustrative only.
final List<FounderPerformancePoint> kFounderPerformanceSeries = [
  FounderPerformancePoint(DateTime(2025, 1, 1), 1_000_000),
  FounderPerformancePoint(DateTime(2025, 2, 1), 1_012_000),
  FounderPerformancePoint(DateTime(2025, 3, 1), 1_028_500),
  FounderPerformancePoint(DateTime(2025, 4, 1), 1_041_200),
  FounderPerformancePoint(DateTime(2025, 5, 1), 1_055_800),
  FounderPerformancePoint(DateTime(2025, 6, 1), 1_063_400),
  FounderPerformancePoint(DateTime(2025, 7, 1), 1_072_100),
  FounderPerformancePoint(DateTime(2025, 8, 1), 1_089_000),
  FounderPerformancePoint(DateTime(2025, 9, 1), 1_101_500),
  FounderPerformancePoint(DateTime(2025, 10, 1), 1_112_800),
  FounderPerformancePoint(DateTime(2025, 11, 1), 1_124_200),
  FounderPerformancePoint(DateTime(2025, 12, 1), 1_185_000),
];

double founderIllustrativeTotalReturnPct() {
  if (kFounderPerformanceSeries.length < 2) return 0;
  final first = kFounderPerformanceSeries.first.valuePkr;
  final last = kFounderPerformanceSeries.last.valuePkr;
  if (first <= 0) return 0;
  return ((last - first) / first) * 100;
}

double founderIllustrativeNetGainPkr() {
  if (kFounderPerformanceSeries.length < 2) return 0;
  return kFounderPerformanceSeries.last.valuePkr -
      kFounderPerformanceSeries.first.valuePkr;
}
