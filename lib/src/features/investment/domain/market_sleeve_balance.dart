import "package:flutter/foundation.dart";

import "five_market_models.dart";

/// The five P&L sleeves aligned with Daily Markets.
enum MarketSleeve { stock, tech, debt, money, gold }

/// One sleeve’s dashboard display breakdown.
@immutable
class SleeveBalanceEntry {
  const SleeveBalanceEntry({
    required this.sleeve,
    required this.basePkr,
    required this.creditedProfitPkr,
    required this.pendingTodayPkr,
    required this.displayPkr,
  });

  final MarketSleeve sleeve;
  final double basePkr;
  final double creditedProfitPkr;
  final double pendingTodayPkr;
  final double displayPkr;
}

/// Aggregated sleeve balances for Home / Portfolio / Daily markets.
@immutable
class SleeveBalanceSnapshot {
  const SleeveBalanceSnapshot({
    required this.sleeves,
    required this.totalDisplayPkr,
    required this.rawSumDisplayPkr,
    required this.pendingTodayTotalPkr,
    required this.creditedWalletProfitPkr,
    required this.allocationTotalPkr,
    required this.todayFiveMarketCredited,
  });

  final List<SleeveBalanceEntry> sleeves;
  final double totalDisplayPkr;
  final double rawSumDisplayPkr;
  final double pendingTodayTotalPkr;
  final double creditedWalletProfitPkr;
  final double allocationTotalPkr;
  final bool todayFiveMarketCredited;

  SleeveBalanceEntry? operator [](MarketSleeve s) {
    for (final e in sleeves) {
      if (e.sleeve == s) return e;
    }
    return null;
  }
}

double _n(dynamic v) {
  if (v is num && v.isFinite) return v.toDouble();
  return 0;
}

/// Extract [profitPkr] for a sleeve key from a `five_market_daily` doc `markets` map.
double profitPkrFromMarketsMap(Map<String, dynamic>? markets, String key) {
  if (markets == null) return 0;
  final o = markets[key];
  if (o is! Map) return 0;
  final m = o.cast<String, dynamic>();
  return _n(m["profitPkr"]);
}

/// Sum attributed [profitPkr] per sleeve for credited daily rows (any doc with `creditedToWallet == true`).
Map<MarketSleeve, double> sumCreditedProfitsBySleeve(
  Iterable<Map<String, dynamic>> creditedDailyDocs,
) {
  final acc = {
    MarketSleeve.stock: 0.0,
    MarketSleeve.tech: 0.0,
    MarketSleeve.debt: 0.0,
    MarketSleeve.money: 0.0,
    MarketSleeve.gold: 0.0,
  };
  for (final d in creditedDailyDocs) {
    if (d["creditedToWallet"] != true) continue;
    final markets = d["markets"] is Map
        ? (d["markets"] as Map).cast<String, dynamic>()
        : null;
    acc[MarketSleeve.stock] =
        acc[MarketSleeve.stock]! + profitPkrFromMarketsMap(markets, "stock");
    acc[MarketSleeve.tech] =
        acc[MarketSleeve.tech]! + profitPkrFromMarketsMap(markets, "tech");
    acc[MarketSleeve.debt] =
        acc[MarketSleeve.debt]! + profitPkrFromMarketsMap(markets, "debt");
    acc[MarketSleeve.money] =
        acc[MarketSleeve.money]! + profitPkrFromMarketsMap(markets, "money");
    acc[MarketSleeve.gold] =
        acc[MarketSleeve.gold]! + profitPkrFromMarketsMap(markets, "gold");
  }
  return acc;
}

/// Whether today’s `five_market_daily/{todayPkt}` is already credited to wallet.
bool todayDocCredited(Map<String, dynamic>? todayDoc) {
  if (todayDoc == null) return false;
  return todayDoc["creditedToWallet"] == true;
}

/// Build snapshot. Non-money bases are pct×[allocationTotal] (already includes wallet profit).
/// Non-money: display = base + pending only — [creditedBySleeve] is tracked for MM and optional UI.
/// Money: display = [moneyBase] + credited money (backend does not move profit into MM) + pending.
SleeveBalanceSnapshot buildSleeveBalanceSnapshot({
  required double allocationTotalPkr,
  required double creditedWalletProfitPkr,
  required double moneyMarketBasePkr,
  required FiveMarketAllocations allocations,
  required Map<MarketSleeve, double> creditedBySleeve,
  required FiveMarketDailyResult? todayResult,
  required bool todayCreditedToWallet,
}) {
  double pendingFor(MarketSleeve s) {
    if (todayCreditedToWallet || todayResult == null || !todayResult.isTradingDay) {
      return 0;
    }
    final sl = switch (s) {
      MarketSleeve.stock => todayResult.stock,
      MarketSleeve.tech => todayResult.tech,
      MarketSleeve.debt => todayResult.debt,
      MarketSleeve.money => todayResult.money,
      MarketSleeve.gold => todayResult.gold,
    };
    return sl.profitPkr;
  }

  double baseNonMm(double pct) {
    if (!allocationTotalPkr.isFinite || allocationTotalPkr <= 0) return 0;
    return double.parse(
      (allocationTotalPkr * pct / 100).toStringAsFixed(2),
    );
  }

  final pendingTotal = todayCreditedToWallet || todayResult == null || !todayResult.isTradingDay
      ? 0.0
      : todayResult.totalProfitPkr;

  const order = [
    MarketSleeve.stock,
    MarketSleeve.tech,
    MarketSleeve.debt,
    MarketSleeve.money,
    MarketSleeve.gold,
  ];

  final entries = <SleeveBalanceEntry>[];
  double rawSum = 0;

  for (final s in order) {
    final pct = switch (s) {
      MarketSleeve.stock => allocations.stock,
      MarketSleeve.tech => allocations.tech,
      MarketSleeve.debt => allocations.debt,
      MarketSleeve.money => allocations.money,
      MarketSleeve.gold => allocations.gold,
    };
    final pend = pendingFor(s);
    late final double base;
    late final double credited;
    late final double display;

    if (s == MarketSleeve.money) {
      base = moneyMarketBasePkr;
      credited = creditedBySleeve[MarketSleeve.money] ?? 0;
      display = double.parse((base + credited + pend).toStringAsFixed(2));
    } else {
      base = baseNonMm(pct);
      credited = 0; // included in allocationTotal via wallet totalProfit
      display = double.parse((base + pend).toStringAsFixed(2));
    }

    entries.add(
      SleeveBalanceEntry(
        sleeve: s,
        basePkr: base,
        creditedProfitPkr: credited,
        pendingTodayPkr: pend,
        displayPkr: display,
      ),
    );
    rawSum += display;
  }

  final target = double.parse(
    (allocationTotalPkr + pendingTotal).toStringAsFixed(2),
  );
  const eps = 0.05;
  double totalDisplay = rawSum;
  List<SleeveBalanceEntry> finalEntries = entries;
  if (rawSum > 0 && (rawSum - target).abs() > eps) {
    final scale = target / rawSum;
    totalDisplay = target;
    finalEntries = [
      for (final e in entries)
        SleeveBalanceEntry(
          sleeve: e.sleeve,
          basePkr: e.basePkr,
          creditedProfitPkr: e.creditedProfitPkr,
          pendingTodayPkr: e.pendingTodayPkr,
          displayPkr: double.parse((e.displayPkr * scale).toStringAsFixed(2)),
        ),
    ];
  } else {
    totalDisplay = double.parse(rawSum.toStringAsFixed(2));
  }

  return SleeveBalanceSnapshot(
    sleeves: finalEntries,
    totalDisplayPkr: totalDisplay,
    rawSumDisplayPkr: double.parse(rawSum.toStringAsFixed(2)),
    pendingTodayTotalPkr: double.parse(pendingTotal.toStringAsFixed(2)),
    creditedWalletProfitPkr: creditedWalletProfitPkr,
    allocationTotalPkr: allocationTotalPkr,
    todayFiveMarketCredited: todayCreditedToWallet,
  );
}
