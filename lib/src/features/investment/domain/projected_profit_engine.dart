enum LiveProfitRange { second, minute, day, month }

class ProjectedProfitSnapshot {
  const ProjectedProfitSnapshot({
    required this.projectedValue,
    required this.projectedProfit,
    required this.elapsed,
  });

  final double projectedValue;
  final double projectedProfit;
  final Duration elapsed;
}

class ProjectedChartPoint {
  const ProjectedChartPoint({required this.time, required this.value});

  final DateTime time;
  final double value;
}

class ProjectedProfitEngine {
  static const double _secondsPerYear = 365 * 24 * 60 * 60;

  const ProjectedProfitEngine._();

  static ProjectedProfitSnapshot project({
    required double baseAmount,
    required double annualRatePct,
    required DateTime baseTimestamp,
    required DateTime now,
  }) {
    final safeBase = baseAmount < 0 ? 0.0 : baseAmount;
    final safeRate = annualRatePct.clamp(0.0, 100.0);
    final elapsed = now.isAfter(baseTimestamp)
        ? now.difference(baseTimestamp)
        : Duration.zero;
    if (safeBase <= 0 || safeRate <= 0 || elapsed == Duration.zero) {
      return ProjectedProfitSnapshot(
        projectedValue: safeBase,
        projectedProfit: 0,
        elapsed: elapsed,
      );
    }

    final elapsedSeconds = elapsed.inMilliseconds / 1000.0;
    final annualProfit = safeBase * (safeRate / 100.0);
    final perSecondProfit = annualProfit / _secondsPerYear;
    final projectedProfit = perSecondProfit * elapsedSeconds;
    final projectedValue = safeBase + projectedProfit;
    return ProjectedProfitSnapshot(
      projectedValue: projectedValue,
      projectedProfit: projectedProfit,
      elapsed: elapsed,
    );
  }

  static List<ProjectedChartPoint> buildSeries({
    required double baseAmount,
    required double annualRatePct,
    required DateTime baseTimestamp,
    required DateTime now,
    required LiveProfitRange range,
  }) {
    final (count, step) = switch (range) {
      LiveProfitRange.second => (120, const Duration(seconds: 1)),
      LiveProfitRange.minute => (120, const Duration(seconds: 30)),
      LiveProfitRange.day => (24, const Duration(hours: 1)),
      LiveProfitRange.month => (30, const Duration(days: 1)),
    };

    final start = now.subtract(
      Duration(milliseconds: step.inMilliseconds * (count - 1)),
    );

    final points = <ProjectedChartPoint>[];
    for (var i = 0; i < count; i++) {
      final t = DateTime.fromMillisecondsSinceEpoch(
        start.millisecondsSinceEpoch + (i * step.inMilliseconds),
      );
      final snapshot = project(
        baseAmount: baseAmount,
        annualRatePct: annualRatePct,
        baseTimestamp: baseTimestamp,
        now: t.isAfter(now) ? now : t,
      );
      points.add(ProjectedChartPoint(time: t, value: snapshot.projectedValue));
    }
    return points;
  }
}
