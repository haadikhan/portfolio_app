import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:portfolio_app/src/features/investment/providers/five_market_providers.dart";
import "package:portfolio_app/src/features/market/data/kmi30_seed_companies.dart";
import "package:portfolio_app/src/features/market/data/models/kmi30_tick.dart";
import "package:portfolio_app/src/features/market/presentation/providers/kmi30_companies_providers.dart";

/// Equal-weight virtual slice of the investor's KMI-30 stock allocation per company.
class Kmi30CompanyAllocation {
  const Kmi30CompanyAllocation({
    required this.symbol,
    required this.name,
    required this.investedPkr,
    required this.currentValuePkr,
    required this.todayProfitPkr,
    required this.todayChangePct,
  });

  final String symbol;
  final String name;
  final double investedPkr;
  final double currentValuePkr;
  final double todayProfitPkr;

  /// Display percent (same normalization as [displayKmi30Percent]).
  final double todayChangePct;

  bool get hasInvestment => investedPkr > 0;
}

double _r2(double v) => double.parse(v.toStringAsFixed(2));

/// Divides today's stock sleeve PKR equally across KMI-30 seed companies; per-row
/// P/L uses each company's live or REST day change percent.
final kmi30CompanyAllocationsProvider =
    Provider<List<Kmi30CompanyAllocation>>((ref) {
  final dailyResult = ref.watch(fiveMarketDailyResultProvider);
  final stockAlloc = dailyResult?.stock.allocatedPkr ?? 0.0;
  final n = kmi30SeedCompanies.length;
  final perCompany = n > 0 ? stockAlloc / n : 0.0;

  return kmi30SeedCompanies.map((c) {
    final live =
        ref.watch(selectedCompanyLiveTickStreamProvider(c.symbol)).valueOrNull;
    final rest = ref.watch(kmi30RestTickProvider(c.symbol)).valueOrNull;
    final tick = live ?? rest;
    final rawPct = tick?.changePercent ?? 0.0;
    final pct = displayKmi30Percent(rawPct);
    final invested = _r2(perCompany);
    final profit = invested == 0 ? 0.0 : _r2(invested * pct / 100);
    final current = _r2(invested + profit);

    return Kmi30CompanyAllocation(
      symbol: c.symbol,
      name: c.name,
      investedPkr: invested,
      currentValuePkr: current,
      todayProfitPkr: profit,
      todayChangePct: pct,
    );
  }).toList();
});
