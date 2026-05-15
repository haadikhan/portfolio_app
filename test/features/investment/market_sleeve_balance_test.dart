import "package:flutter_test/flutter_test.dart";

import "package:portfolio_app/src/features/investment/domain/five_market_daily_engine.dart";
import "package:portfolio_app/src/features/investment/domain/five_market_models.dart";
import "package:portfolio_app/src/features/investment/domain/market_sleeve_balance.dart";

void main() {
  group("sumCreditedProfitsBySleeve", () {
    test("sums only credited docs", () {
      final m = sumCreditedProfitsBySleeve([
        {
          "creditedToWallet": true,
          "markets": {
            "stock": {"profitPkr": 10},
            "money": {"profitPkr": 2},
          },
        },
        {
          "creditedToWallet": false,
          "markets": {
            "stock": {"profitPkr": 99},
          },
        },
      ]);
      expect(m[MarketSleeve.stock], 10);
      expect(m[MarketSleeve.money], 2);
    });
  });

  group("todayDocCredited", () {
    test("null is false", () {
      expect(todayDocCredited(null), isFalse);
    });
    test("true when credited", () {
      expect(todayDocCredited({"creditedToWallet": true}), isTrue);
    });
  });

  group("buildSleeveBalanceSnapshot", () {
    const config = FiveMarketConfig();
    final todayResult = FiveMarketDailyEngine.calculate(
      basePkr: 100000,
      config: config,
      tradingDay: const TradingDayResult(
        isTradingDay: true,
        source: TradingDaySource.calendar,
      ),
      kmi30Percent: 1,
      goldPercent: 0.5,
      isIntraday: false,
    );

    test("money sleeve includes credited money profits", () {
      final snap = buildSleeveBalanceSnapshot(
        allocationTotalPkr: 100000,
        creditedWalletProfitPkr: 0,
        moneyMarketBasePkr: 4000,
        allocations: config.allocations,
        creditedBySleeve: {
          MarketSleeve.stock: 0,
          MarketSleeve.tech: 0,
          MarketSleeve.debt: 0,
          MarketSleeve.money: 50,
          MarketSleeve.gold: 0,
        },
        todayResult: todayResult,
        todayCreditedToWallet: false,
      );
      final mm = snap[MarketSleeve.money]!;
      expect(mm.basePkr, 4000);
      expect(mm.creditedProfitPkr, 50);
      expect(mm.pendingTodayPkr, todayResult.money.profitPkr);
    });

    test("pending cleared when today credited", () {
      final snap = buildSleeveBalanceSnapshot(
        allocationTotalPkr: 100000,
        creditedWalletProfitPkr: 100,
        moneyMarketBasePkr: 5000,
        allocations: config.allocations,
        creditedBySleeve: {},
        todayResult: todayResult,
        todayCreditedToWallet: true,
      );
      expect(snap.pendingTodayTotalPkr, 0);
      for (final e in snap.sleeves) {
        expect(e.pendingTodayPkr, 0);
      }
    });

    test("non-trading day no pending", () {
      final snap = buildSleeveBalanceSnapshot(
        allocationTotalPkr: 100000,
        creditedWalletProfitPkr: 0,
        moneyMarketBasePkr: 5000,
        allocations: config.allocations,
        creditedBySleeve: {},
        todayResult: FiveMarketDailyResult.nonTradingDay(
          basePkr: 100000,
          config: config,
          source: TradingDaySource.weekend,
        ),
        todayCreditedToWallet: false,
      );
      expect(snap.pendingTodayTotalPkr, 0);
    });
  });
}
