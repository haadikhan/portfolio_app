import "package:flutter_test/flutter_test.dart";

import "package:portfolio_app/src/features/investment/domain/five_market_daily_engine.dart";
import "package:portfolio_app/src/features/investment/domain/five_market_models.dart";

void main() {
  const config = FiveMarketConfig();
  const base = 100000.0;

  group("resolveTradingDay", () {
    const holidays = [
      PkHoliday(date: "2026-03-23", name: "Pakistan Day"),
    ];

    test("normal weekday is open", () {
      final r = FiveMarketDailyEngine.resolveTradingDay(
        datePkt: "2026-03-24",
        holidays: holidays,
      );
      expect(r.isTradingDay, isTrue);
      expect(r.source, TradingDaySource.calendar);
    });

    test("Saturday is closed", () {
      final r = FiveMarketDailyEngine.resolveTradingDay(
        datePkt: "2026-03-21",
        holidays: holidays,
      );
      expect(r.isTradingDay, isFalse);
      expect(r.source, TradingDaySource.weekend);
    });

    test("Sunday is closed", () {
      final r = FiveMarketDailyEngine.resolveTradingDay(
        datePkt: "2026-03-22",
        holidays: holidays,
      );
      expect(r.isTradingDay, isFalse);
      expect(r.source, TradingDaySource.weekend);
    });

    test("seeded PK holiday is closed", () {
      final r = FiveMarketDailyEngine.resolveTradingDay(
        datePkt: "2026-03-23",
        holidays: holidays,
      );
      expect(r.isTradingDay, isFalse);
      expect(r.source, TradingDaySource.holiday);
    });

    test("forceClosedAll on Tuesday overrides open", () {
      final r = FiveMarketDailyEngine.resolveTradingDay(
        datePkt: "2026-03-24",
        holidays: holidays,
        override: const FiveMarketDayOverride(
          date: "2026-03-24",
          forceClosedAll: true,
          reason: "Unexpected strike",
        ),
      );
      expect(r.isTradingDay, isFalse);
      expect(r.source, TradingDaySource.forceClosed);
    });

    test("forceOpenDailyProfits on Sunday overrides closed", () {
      final r = FiveMarketDailyEngine.resolveTradingDay(
        datePkt: "2026-03-22",
        holidays: holidays,
        override: const FiveMarketDayOverride(
          date: "2026-03-22",
          forceOpenDailyProfits: true,
          reason: "Special trading session",
        ),
      );
      expect(r.isTradingDay, isTrue);
      expect(r.source, TradingDaySource.forceOpen);
    });

    test("forceOpen wins over holiday", () {
      final r = FiveMarketDailyEngine.resolveTradingDay(
        datePkt: "2026-03-23",
        holidays: holidays,
        override: const FiveMarketDayOverride(
          date: "2026-03-23",
          forceOpenDailyProfits: true,
          reason: "Emergency session",
        ),
      );
      expect(r.isTradingDay, isTrue);
      expect(r.source, TradingDaySource.forceOpen);
    });
  });

  group("calculate — non-trading day", () {
    test("all profits are zero on Saturday", () {
      final tradingDay = FiveMarketDailyEngine.resolveTradingDay(
        datePkt: "2026-03-21",
        holidays: const [],
      );
      final result = FiveMarketDailyEngine.calculate(
        basePkr: base,
        config: config,
        tradingDay: tradingDay,
        kmi30Percent: 0.5,
        goldPercent: 0.3,
      );
      expect(result.isTradingDay, isFalse);
      expect(result.totalProfitPkr, 0);
      expect(result.stock.profitPkr, 0);
      expect(result.gold.profitPkr, 0);
      expect(result.tech.profitPkr, 0);
      expect(result.debt.profitPkr, 0);
      expect(result.money.profitPkr, 0);
    });
  });

  group("calculate — trading day PKR 100k", () {
    const openDay = TradingDayResult(
      isTradingDay: true,
      source: TradingDaySource.calendar,
    );

    test("stock calculation: 40k * 0.03% = PKR 12", () {
      final r = FiveMarketDailyEngine.calculate(
        basePkr: base,
        config: config,
        tradingDay: openDay,
        kmi30Percent: 0.03,
        goldPercent: 0,
      );
      expect(r.stock.allocatedPkr, 40000);
      expect(r.stock.profitPkr, 12.0);
    });

    test("tech calculation: 25k * 100% / 365 = PKR 68.49", () {
      final r = FiveMarketDailyEngine.calculate(
        basePkr: base,
        config: config,
        tradingDay: openDay,
        kmi30Percent: 0,
        goldPercent: 0,
      );
      expect(r.tech.allocatedPkr, 25000);
      expect(r.tech.profitPkr, closeTo(68.49, 0.01));
    });

    test("debt calculation: 25k * 18% / 365 = PKR 12.33", () {
      final r = FiveMarketDailyEngine.calculate(
        basePkr: base,
        config: config,
        tradingDay: openDay,
        kmi30Percent: 0,
        goldPercent: 0,
      );
      expect(r.debt.allocatedPkr, 25000);
      expect(r.debt.profitPkr, closeTo(12.33, 0.01));
    });

    test("money calculation: 5k * 15% / 365 = PKR 2.05", () {
      final r = FiveMarketDailyEngine.calculate(
        basePkr: base,
        config: config,
        tradingDay: openDay,
        kmi30Percent: 0,
        goldPercent: 0,
      );
      expect(r.money.allocatedPkr, 5000);
      expect(r.money.profitPkr, closeTo(2.05, 0.01));
    });

    test("gold calculation: 5k * 0.18% = PKR 9", () {
      final r = FiveMarketDailyEngine.calculate(
        basePkr: base,
        config: config,
        tradingDay: openDay,
        kmi30Percent: 0,
        goldPercent: 0.18,
      );
      expect(r.gold.allocatedPkr, 5000);
      expect(r.gold.profitPkr, 9.0);
    });

    test("stock negative: 40k * -0.87% = PKR -348", () {
      final r = FiveMarketDailyEngine.calculate(
        basePkr: base,
        config: config,
        tradingDay: openDay,
        kmi30Percent: -0.87,
        goldPercent: 0,
      );
      expect(r.stock.profitPkr, closeTo(-348.0, 0.01));
    });

    test("total profit sums all five markets correctly", () {
      final r = FiveMarketDailyEngine.calculate(
        basePkr: base,
        config: config,
        tradingDay: openDay,
        kmi30Percent: 0.03,
        goldPercent: 0.18,
      );
      final expected = r.stock.profitPkr +
          r.tech.profitPkr +
          r.debt.profitPkr +
          r.money.profitPkr +
          r.gold.profitPkr;
      expect(r.totalProfitPkr, closeTo(expected, 0.01));
    });

    test("status is LIVE when isIntraday true", () {
      final r = FiveMarketDailyEngine.calculate(
        basePkr: base,
        config: config,
        tradingDay: openDay,
        kmi30Percent: 0.03,
        goldPercent: 0.18,
        isIntraday: true,
      );
      expect(r.stock.status, MarketSliceStatus.live);
    });

    test("status is REALIZED when isIntraday false", () {
      final r = FiveMarketDailyEngine.calculate(
        basePkr: base,
        config: config,
        tradingDay: openDay,
        kmi30Percent: 0.03,
        goldPercent: 0.18,
        isIntraday: false,
      );
      expect(r.stock.status, MarketSliceStatus.realized);
    });
  });
}
