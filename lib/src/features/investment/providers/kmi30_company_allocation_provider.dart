import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:portfolio_app/src/features/investment/providers/five_market_providers.dart";
import "package:portfolio_app/src/features/market/data/kmi30_seed_companies.dart"
    show assertKmi30WeightSum, kmi30SeedCompanies;
import "package:portfolio_app/src/features/market/data/models/kmi30_tick.dart";
import "package:portfolio_app/src/features/market/presentation/providers/kmi30_companies_providers.dart";

/// Weight-based virtual slice of the investor's KMI-30 stock allocation per company.
class Kmi30CompanyAllocation {
  const Kmi30CompanyAllocation({
    required this.symbol,
    required this.name,
    required this.investedPkr,
    required this.currentValuePkr,
    required this.todayProfitPkr,
    required this.todayChangePct,
    required this.weightPercent,
  });

  final String symbol;
  final String name;
  final double investedPkr;
  final double currentValuePkr;
  final double todayProfitPkr;

  /// Display percent (same normalization as [displayKmi30Percent]).
  final double todayChangePct;

  final double weightPercent;

  bool get hasInvestment => investedPkr > 0;
}

double _r2(double v) => double.parse(v.toStringAsFixed(2));

/// Prefer live tick when it has day change; otherwise REST (more reliable off-peak).
Kmi30Tick? selectKmi30CompanyTick(Kmi30Tick? live, Kmi30Tick? rest) {
  if (live != null && live.changePercent != 0.0) return live;
  if (rest != null && rest.changePercent != 0.0) return rest;
  return live ?? rest;
}

/// Per-company breakdown of stock sleeve using KMI30 index weights.
final kmi30CompanyAllocationsProvider =
    Provider<List<Kmi30CompanyAllocation>>((ref) {
  assertKmi30WeightSum();
  final dailyResult = ref.watch(fiveMarketDailyResultProvider);
  final stockAlloc = dailyResult?.stock.allocatedPkr ?? 0.0;

  return kmi30SeedCompanies.map((c) {
    final live =
        ref.watch(selectedCompanyLiveTickStreamProvider(c.symbol)).valueOrNull;
    final rest = ref.watch(kmi30RestTickProvider(c.symbol)).valueOrNull;
    final tick = selectKmi30CompanyTick(live, rest);
    final rawPct = tick?.changePercent ?? 0.0;
    final pct = displayKmi30Percent(rawPct);
    final invested = _r2(stockAlloc * c.weightPercent / 100);
    final profit = invested == 0 ? 0.0 : _r2(invested * pct / 100);
    final current = _r2(invested + profit);

    return Kmi30CompanyAllocation(
      symbol: c.symbol,
      name: c.name,
      investedPkr: invested,
      currentValuePkr: current,
      todayProfitPkr: profit,
      todayChangePct: pct,
      weightPercent: c.weightPercent,
    );
  }).toList();
});
