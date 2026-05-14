import "package:portfolio_app/src/features/investment/domain/five_market_models.dart";

/// Pure Dart engine — no Flutter imports, no Riverpod.
/// Mirrors deployed JS `calculateDailyProfit` + `resolveTradingDay` behavior.
class FiveMarketDailyEngine {
  FiveMarketDailyEngine._();

  /// Resolve whether a date (yyyy-MM-dd PKT) is a trading day.
  /// Resolution order (matches Cloud Function):
  /// 1. forceOpenDailyProfits = true  → OPEN
  /// 2. forceClosedAll        = true  → CLOSED
  /// 3. Saturday or Sunday            → CLOSED
  /// 4. In seeded PK holiday list     → CLOSED
  /// 5. Otherwise                     → OPEN
  static TradingDayResult resolveTradingDay({
    required String datePkt,
    required List<PkHoliday> holidays,
    FiveMarketDayOverride? override,
  }) {
    if (override?.forceOpenDailyProfits == true) {
      return const TradingDayResult(
        isTradingDay: true,
        source: TradingDaySource.forceOpen,
      );
    }
    if (override?.forceClosedAll == true) {
      return const TradingDayResult(
        isTradingDay: false,
        source: TradingDaySource.forceClosed,
      );
    }

    final parts = datePkt.split("-");
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        final wd = DateTime.utc(y, m, d).weekday;
        if (wd == DateTime.saturday || wd == DateTime.sunday) {
          return const TradingDayResult(
            isTradingDay: false,
            source: TradingDaySource.weekend,
          );
        }
      }
    }

    if (holidays.any((h) => h.date == datePkt)) {
      return const TradingDayResult(
        isTradingDay: false,
        source: TradingDaySource.holiday,
      );
    }

    return const TradingDayResult(
      isTradingDay: true,
      source: TradingDaySource.calendar,
    );
  }

  /// Calculate five-market daily profit.
  /// Returns [FiveMarketDailyResult.nonTradingDay] when [tradingDay.isTradingDay] is false.
  static FiveMarketDailyResult calculate({
    required double basePkr,
    required FiveMarketConfig config,
    required TradingDayResult tradingDay,
    required double kmi30Percent,
    required double goldPercent,
    bool isIntraday = true,
  }) {
    if (!tradingDay.isTradingDay) {
      return FiveMarketDailyResult.nonTradingDay(
        basePkr: basePkr,
        config: config,
        source: tradingDay.source,
      );
    }

    final a = config.allocations;
    final r = config.rates;

    double allocated(double pct) => basePkr * pct / 100;
    double round2(double v) => double.parse(v.toStringAsFixed(2));

    final stockAlloc = allocated(a.stock);
    final stockProfit = round2(stockAlloc * kmi30Percent / 100);

    final techAlloc = allocated(a.tech);
    final techProfit =
        round2(techAlloc * r.techBenchmarkAnnualPercent / 100 / 365);

    final debtAlloc = allocated(a.debt);
    final debtProfit = round2(debtAlloc * r.debtAnnualPercent / 100 / 365);

    final moneyAlloc = allocated(a.money);
    final moneyProfit = round2(moneyAlloc * r.moneyAnnualPercent / 100 / 365);

    final goldAlloc = allocated(a.gold);
    final goldProfit = round2(goldAlloc * goldPercent / 100);

    final totalProfit = round2(
      stockProfit + techProfit + debtProfit + moneyProfit + goldProfit,
    );

    final sliceStatus =
        isIntraday ? MarketSliceStatus.live : MarketSliceStatus.realized;

    return FiveMarketDailyResult(
      basePkr: basePkr,
      isTradingDay: true,
      tradingDaySource: tradingDay.source,
      stock: MarketSliceResult(
        allocatedPkr: round2(stockAlloc),
        profitPkr: stockProfit,
        changePercent: kmi30Percent,
        status: sliceStatus,
      ),
      tech: MarketSliceResult(
        allocatedPkr: round2(techAlloc),
        profitPkr: techProfit,
        changePercent: 0,
        annualPercent: r.techBenchmarkAnnualPercent,
        status: sliceStatus,
      ),
      debt: MarketSliceResult(
        allocatedPkr: round2(debtAlloc),
        profitPkr: debtProfit,
        changePercent: 0,
        annualPercent: r.debtAnnualPercent,
        status: sliceStatus,
      ),
      money: MarketSliceResult(
        allocatedPkr: round2(moneyAlloc),
        profitPkr: moneyProfit,
        changePercent: 0,
        annualPercent: r.moneyAnnualPercent,
        status: sliceStatus,
      ),
      gold: MarketSliceResult(
        allocatedPkr: round2(goldAlloc),
        profitPkr: goldProfit,
        changePercent: goldPercent,
        status: sliceStatus,
      ),
      totalProfitPkr: totalProfit,
    );
  }
}
