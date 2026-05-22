import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "package:portfolio_app/src/features/investment/data/models/sleeve_purchase_entry.dart";
import "package:portfolio_app/src/features/investment/domain/five_market_models.dart";
import "package:portfolio_app/src/features/investment/domain/market_sleeve_balance.dart";
import "package:portfolio_app/src/features/investment/presentation/market_detail/market_detail_providers.dart";
import "package:portfolio_app/src/features/investment/providers/five_market_providers.dart";
import "package:portfolio_app/src/features/market/data/gold_units.dart";
import "package:portfolio_app/src/features/market/data/models/kmi30_bar.dart";
import "package:portfolio_app/src/features/market/presentation/providers/kmi30_companies_providers.dart";
import "package:portfolio_app/src/providers/transaction_history_providers.dart";

final _dateFmt = DateFormat("yyyy-MM-dd");

// ─── Provider ────────────────────────────────────────────────────────────────

final sleevePurchaseEntriesProvider = AsyncNotifierProvider.family<
    SleevePurchaseReportNotifier,
    List<SleevePurchaseEntry>,
    MarketSleeve>(SleevePurchaseReportNotifier.new);

/// Invalidates the provider so the next `.future` read re-fetches.
void refreshSleevePurchaseReport(Ref ref, MarketSleeve sleeve) =>
    ref.invalidate(sleevePurchaseEntriesProvider(sleeve));

// ─── Notifier ─────────────────────────────────────────────────────────────────

class SleevePurchaseReportNotifier
    extends FamilyAsyncNotifier<List<SleevePurchaseEntry>, MarketSleeve> {
  @override
  Future<List<SleevePurchaseEntry>> build(MarketSleeve arg) async {
    final sleeve = arg;
    final cfg =
        ref.read(fiveMarketConfigProvider).valueOrNull ?? FiveMarketConfig();

    // 1. Get transactions — one-shot read so stream re-emits don't restart
    //    this build in a loop.  Falls back to awaiting the future when the
    //    stream hasn't emitted yet (e.g. first access after cold launch).
    final txnsAsync = ref.read(userTransactionItemsProvider);
    final txns = txnsAsync.hasValue
        ? txnsAsync.value!
        : await ref.read(userTransactionItemsProvider.future);
    final deposits = txns
        .where((t) => t.type == "deposit" && t.status == "approved")
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (deposits.isEmpty) return [];

    // 2. Allocation percentage for this sleeve.
    final allocPct = _allocPct(cfg, sleeve);

    // 3. Build kline map and fetch current price.
    final klineMap = await _buildKlineMap(sleeve, cfg);
    final currentPrice = await _currentPriceFor(sleeve, cfg);

    // 4. Build entries.
    final entries = <SleevePurchaseEntry>[];
    for (var i = 0; i < deposits.length; i++) {
      final dep = deposits[i];
      final investedPkr = dep.amount * allocPct / 100;
      final dateKey = _dateFmt.format(dep.createdAt.toLocal());

      late SleevePurchaseEntry entry;

      // Convert UTC Firestore timestamp to local for display and filtering.
      final depositDateLocal = dep.createdAt.toLocal();

      if (sleeve == MarketSleeve.gold || sleeve == MarketSleeve.stock) {
        final purchasePx = klineMap[dateKey];
        final tolas = (purchasePx != null && purchasePx > 0)
            ? investedPkr / purchasePx
            : null;
        entry = SleevePurchaseEntry(
          sno: i + 1,
          depositDate: depositDateLocal,
          depositTotal: dep.amount,
          investedPkr: investedPkr,
          purchasePricePerTola: purchasePx,
          tolasBought: tolas,
          currentPricePerTola: currentPrice,
          note: dep.note,
        );
      } else {
        // tech / debt / money — rate-based
        final rate = _rateForSleeve(cfg, sleeve);
        final days = DateTime.now()
            .difference(dep.createdAt)
            .inDays
            .clamp(0, 36500);
        final pnl = investedPkr * (rate / 100) * (days / 365);
        entry = SleevePurchaseEntry(
          sno: i + 1,
          depositDate: depositDateLocal,
          depositTotal: dep.amount,
          investedPkr: investedPkr,
          purchasePricePerTola: rate,
          tolasBought: null,
          currentPricePerTola: currentPrice,
          precomputedPnl: pnl,
          note: dep.note,
        );
      }
      entries.add(entry);
    }
    return entries;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  double _allocPct(FiveMarketConfig cfg, MarketSleeve sleeve) => switch (sleeve) {
        MarketSleeve.stock => cfg.allocations.stock,
        MarketSleeve.tech => cfg.allocations.tech,
        MarketSleeve.debt => cfg.allocations.debt,
        MarketSleeve.money => cfg.allocations.money,
        MarketSleeve.gold => cfg.allocations.gold,
      };

  double _rateForSleeve(FiveMarketConfig cfg, MarketSleeve sleeve) =>
      switch (sleeve) {
        MarketSleeve.tech => cfg.rates.techBenchmarkAnnualPercent,
        MarketSleeve.debt => cfg.rates.debtAnnualPercent,
        MarketSleeve.money => cfg.rates.moneyAnnualPercent,
        _ => 0.0,
      };

  Future<double?> _currentPriceFor(
    MarketSleeve sleeve,
    FiveMarketConfig cfg,
  ) async {
    switch (sleeve) {
      case MarketSleeve.gold:
        return Future.value(ref.read(goldPricePerTolaProvider));
      case MarketSleeve.stock:
        final tick = await ref
            .read(psxRepositoryProvider)
            .fetchIndexTick("KMI30");
        return tick?.currentValue;
      case MarketSleeve.tech:
        return Future.value(cfg.rates.techBenchmarkAnnualPercent);
      case MarketSleeve.debt:
        return Future.value(cfg.rates.debtAnnualPercent);
      case MarketSleeve.money:
        return Future.value(cfg.rates.moneyAnnualPercent);
    }
  }

  Future<Map<String, double>> _buildKlineMap(
    MarketSleeve sleeve,
    FiveMarketConfig cfg,
  ) async {
    if (sleeve == MarketSleeve.gold) {
      final bars = await ref
          .read(goldPriceRepositoryProvider)
          .fetchPaxgKlinesPkr("1d", limit: 365);
      return _barsToMap(bars, toTola: true);
    } else if (sleeve == MarketSleeve.stock) {
      final bars = await ref
          .read(psxRepositoryProvider)
          .fetchKlines("KMI30", "1d", limit: 365);
      return _barsToMap(bars, toTola: false);
    }
    return {};
  }

  Map<String, double> _barsToMap(List<Kmi30Bar> bars, {required bool toTola}) {
    final map = <String, double>{};
    for (final bar in bars) {
      final key = _dateFmt.format(bar.timestamp.toLocal());
      final value = toTola ? pkrPerTolaFromPkrPerTroyOz(bar.close) : bar.close;
      map[key] = value;
    }
    return map;
  }
}
