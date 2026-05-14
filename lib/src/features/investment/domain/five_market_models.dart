// Firestore-backed models for the five-market daily feature (Phase 3).

/// Market allocation config from settings/five_market_calc
class FiveMarketAllocations {
  const FiveMarketAllocations({
    this.stock = 40,
    this.tech = 25,
    this.debt = 25,
    this.money = 5,
    this.gold = 5,
  });

  final double stock;
  final double tech;
  final double debt;
  final double money;
  final double gold;

  factory FiveMarketAllocations.fromMap(Map<String, dynamic> m) =>
      FiveMarketAllocations(
        stock: (m["stock"] as num?)?.toDouble() ?? 40,
        tech: (m["tech"] as num?)?.toDouble() ?? 25,
        debt: (m["debt"] as num?)?.toDouble() ?? 25,
        money: (m["money"] as num?)?.toDouble() ?? 5,
        gold: (m["gold"] as num?)?.toDouble() ?? 5,
      );

  /// Validates allocations sum to 100 within tolerance
  bool get isValid =>
      (stock + tech + debt + money + gold - 100).abs() < 0.1;
}

/// Rate config from settings/five_market_calc
class FiveMarketRates {
  const FiveMarketRates({
    this.debtAnnualPercent = 18.0,
    this.moneyAnnualPercent = 15.0,
    this.techBenchmarkAnnualPercent = 100.0,
    this.techTargetAnnualPercent = 500.0,
  });

  final double debtAnnualPercent;
  final double moneyAnnualPercent;
  final double techBenchmarkAnnualPercent;
  final double techTargetAnnualPercent;

  factory FiveMarketRates.fromMap(Map<String, dynamic> m) => FiveMarketRates(
        debtAnnualPercent:
            (m["debtAnnualPercent"] as num?)?.toDouble() ?? 18.0,
        moneyAnnualPercent:
            (m["moneyAnnualPercent"] as num?)?.toDouble() ?? 15.0,
        techBenchmarkAnnualPercent:
            (m["techBenchmarkAnnualPercent"] as num?)?.toDouble() ?? 100.0,
        techTargetAnnualPercent:
            (m["techTargetAnnualPercent"] as num?)?.toDouble() ?? 500.0,
      );
}

/// Combined config document
class FiveMarketConfig {
  const FiveMarketConfig({
    this.allocations = const FiveMarketAllocations(),
    this.rates = const FiveMarketRates(),
  });

  final FiveMarketAllocations allocations;
  final FiveMarketRates rates;

  factory FiveMarketConfig.fromFirestore(Map<String, dynamic> d) =>
      FiveMarketConfig(
        allocations: FiveMarketAllocations.fromMap(
          (d["allocations"] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        ),
        rates: FiveMarketRates.fromMap(
          (d["rates"] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        ),
      );

  static FiveMarketConfig get defaults => const FiveMarketConfig();
}

/// A single Pakistan public holiday entry
class PkHoliday {
  const PkHoliday({
    required this.date,
    required this.name,
    this.isIslamicHoliday = false,
    this.estimatedDate = false,
  });

  final String date;
  final String name;
  final bool isIslamicHoliday;
  final bool estimatedDate;

  factory PkHoliday.fromMap(Map<String, dynamic> m) => PkHoliday(
        date: m["date"] as String? ?? "",
        name: m["name"] as String? ?? "",
        isIslamicHoliday: m["isIslamicHoliday"] as bool? ?? false,
        estimatedDate: m["estimatedDate"] as bool? ?? false,
      );
}

/// Admin day override for a specific date
class FiveMarketDayOverride {
  const FiveMarketDayOverride({
    required this.date,
    this.forceClosedAll = false,
    this.forceOpenDailyProfits = false,
    this.reason = "",
  });

  final String date;
  final bool forceClosedAll;
  final bool forceOpenDailyProfits;
  final String reason;

  factory FiveMarketDayOverride.fromFirestore(Map<String, dynamic> d) =>
      FiveMarketDayOverride(
        date: d["date"] as String? ?? "",
        forceClosedAll: d["forceClosedAll"] as bool? ?? false,
        forceOpenDailyProfits: d["forceOpenDailyProfits"] as bool? ?? false,
        reason: d["reason"] as String? ?? "",
      );
}

/// Source explaining why a day resolved as open or closed
enum TradingDaySource {
  forceOpen,
  forceClosed,
  weekend,
  holiday,
  calendar,
}

/// Result of trading day resolution
class TradingDayResult {
  const TradingDayResult({
    required this.isTradingDay,
    required this.source,
  });

  final bool isTradingDay;
  final TradingDaySource source;
}

/// Status label for a market slice display
enum MarketSliceStatus {
  live,
  realized,
  closed,
  nonTradingDay,
}

/// Per-market calculation result
class MarketSliceResult {
  const MarketSliceResult({
    required this.allocatedPkr,
    required this.profitPkr,
    required this.changePercent,
    this.annualPercent,
    required this.status,
  });

  final double allocatedPkr;
  final double profitPkr;
  final double changePercent;
  final double? annualPercent;
  final MarketSliceStatus status;
}

/// Full five-market engine output
class FiveMarketDailyResult {
  const FiveMarketDailyResult({
    required this.basePkr,
    required this.isTradingDay,
    required this.tradingDaySource,
    required this.stock,
    required this.tech,
    required this.debt,
    required this.money,
    required this.gold,
    required this.totalProfitPkr,
  });

  final double basePkr;
  final bool isTradingDay;
  final TradingDaySource tradingDaySource;
  final MarketSliceResult stock;
  final MarketSliceResult tech;
  final MarketSliceResult debt;
  final MarketSliceResult money;
  final MarketSliceResult gold;
  final double totalProfitPkr;

  /// Zero result for non-trading days
  factory FiveMarketDailyResult.nonTradingDay({
    required double basePkr,
    required FiveMarketConfig config,
    required TradingDaySource source,
  }) {
    MarketSliceResult slice(
      double pct, {
      double? annual,
    }) =>
        MarketSliceResult(
          allocatedPkr: double.parse((basePkr * pct / 100).toStringAsFixed(2)),
          profitPkr: 0,
          changePercent: 0,
          annualPercent: annual,
          status: MarketSliceStatus.nonTradingDay,
        );

    final a = config.allocations;
    final r = config.rates;
    return FiveMarketDailyResult(
      basePkr: basePkr,
      isTradingDay: false,
      tradingDaySource: source,
      stock: slice(a.stock),
      tech: slice(a.tech, annual: r.techBenchmarkAnnualPercent),
      debt: slice(a.debt, annual: r.debtAnnualPercent),
      money: slice(a.money, annual: r.moneyAnnualPercent),
      gold: slice(a.gold),
      totalProfitPkr: 0,
    );
  }
}
