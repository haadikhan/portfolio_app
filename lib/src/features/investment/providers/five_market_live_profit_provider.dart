import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:portfolio_app/src/core/market/market_hours.dart";
import "package:portfolio_app/src/features/investment/data/allocation_money_market.dart";
import "package:portfolio_app/src/features/investment/domain/five_market_daily_engine.dart";
import "package:portfolio_app/src/features/investment/domain/five_market_models.dart";
import "package:portfolio_app/src/features/investment/providers/five_market_providers.dart";
import "package:portfolio_app/src/features/investment/providers/market_sleeve_balance_provider.dart";
import "package:portfolio_app/src/features/market/data/models/kmi30_index_tick.dart";
import "package:portfolio_app/src/features/market/providers/kmi30_index_provider.dart";
import "package:portfolio_app/src/providers/wallet_providers.dart";

/// Counts actual calendar trading days (Mon-Fri minus PK holidays) that have
/// ELAPSED so far within [periodStart, periodEndInclusive] inclusive, using
/// the same [FiveMarketDailyEngine.resolveTradingDay] logic as the daily engine.
/// [periodEndInclusive] is clamped to "yesterday" since today is never counted
/// as elapsed until after EOD credit.
int countElapsedCalendarTradingDays({
  required DateTime periodStart,
  required DateTime periodEndInclusive,
  required List<PkHoliday> holidays,
}) {
  var count = 0;
  var cursor = DateTime(
    periodStart.year,
    periodStart.month,
    periodStart.day,
  );
  final end = DateTime(
    periodEndInclusive.year,
    periodEndInclusive.month,
    periodEndInclusive.day,
  );
  while (!cursor.isAfter(end)) {
    final datePkt =
        "${cursor.year.toString().padLeft(4, '0')}-"
        "${cursor.month.toString().padLeft(2, '0')}-"
        "${cursor.day.toString().padLeft(2, '0')}";
    final result = FiveMarketDailyEngine.resolveTradingDay(
      datePkt: datePkt,
      holidays: holidays,
    );
    if (result.isTradingDay) count++;
    cursor = cursor.add(const Duration(days: 1));
  }
  return count;
}

/// Combines [fiveMarketDailyResultProvider] with periodic refresh for live UI.
class FiveMarketLiveProfitState {
  const FiveMarketLiveProfitState({
    required this.basePkr,
    required this.isTradingDay,
    required this.isMarketHours,
    required this.stockProfitPkr,
    required this.techProfitPkr,
    required this.debtProfitPkr,
    required this.moneyProfitPkr,
    required this.goldProfitPkr,
    required this.totalProfitPkr,
    required this.stockAllocatedPkr,
    required this.techAllocatedPkr,
    required this.debtAllocatedPkr,
    required this.moneyAllocatedPkr,
    required this.goldAllocatedPkr,
    required this.kmi30ChangePercent,
    required this.goldChangePercent,
    required this.techAnnualPercent,
    required this.debtAnnualPercent,
    required this.moneyAnnualPercent,
    required this.stockStatus,
    required this.techStatus,
    required this.debtStatus,
    required this.moneyStatus,
    required this.goldStatus,
  });

  final double basePkr;
  final bool isTradingDay;
  final bool isMarketHours;
  final double stockProfitPkr;
  final double techProfitPkr;
  final double debtProfitPkr;
  final double moneyProfitPkr;
  final double goldProfitPkr;
  final double totalProfitPkr;
  final double stockAllocatedPkr;
  final double techAllocatedPkr;
  final double debtAllocatedPkr;
  final double moneyAllocatedPkr;
  final double goldAllocatedPkr;
  final double kmi30ChangePercent;
  final double goldChangePercent;
  final double techAnnualPercent;
  final double debtAnnualPercent;
  final double moneyAnnualPercent;
  final MarketSliceStatus stockStatus;
  final MarketSliceStatus techStatus;
  final MarketSliceStatus debtStatus;
  final MarketSliceStatus moneyStatus;
  final MarketSliceStatus goldStatus;

  double get totalAllocatedPkr =>
      stockAllocatedPkr +
      techAllocatedPkr +
      debtAllocatedPkr +
      moneyAllocatedPkr +
      goldAllocatedPkr;
}

/// Summary of P&L for a time period (month or year).
class FiveMarketPeriodSummary {
  const FiveMarketPeriodSummary({
    required this.label,
    required this.stockProfitPkr,
    required this.techProfitPkr,
    required this.debtProfitPkr,
    required this.moneyProfitPkr,
    required this.goldProfitPkr,
    required this.calendarTradingDays,
    required this.creditedLedgerDays,
    this.isFromLedger = true,
    this.walletFallbackPkr = 0,
    this.isLoadingHistory = false,
  });

  final String label;
  final double stockProfitPkr;
  final double techProfitPkr;
  final double debtProfitPkr;
  final double moneyProfitPkr;
  final double goldProfitPkr;

  /// Primary count: weekdays minus PK holidays elapsed in the period.
  final int calendarTradingDays;

  /// Secondary count: credited [five_market_daily] docs in the period.
  final int creditedLedgerDays;

  /// Backward-compatible alias for [calendarTradingDays].
  int get tradingDays => calendarTradingDays;

  /// `true` when summed from [five_market_daily]; `false` = wallet fallback.
  final bool isFromLedger;

  /// Used when [isFromLedger] is `false` (no ledger rows for the period).
  final double walletFallbackPkr;

  /// True while history/holiday streams are still loading on first fetch.
  final bool isLoadingHistory;

  double get totalProfitPkr =>
      stockProfitPkr +
      techProfitPkr +
      debtProfitPkr +
      moneyProfitPkr +
      goldProfitPkr;

  /// Hero display: ledger sum or wallet credited profit fallback.
  double get displayTotalPkr =>
      isFromLedger ? totalProfitPkr : walletFallbackPkr;

  static const FiveMarketPeriodSummary zero = FiveMarketPeriodSummary(
    label: "",
    stockProfitPkr: 0,
    techProfitPkr: 0,
    debtProfitPkr: 0,
    moneyProfitPkr: 0,
    goldProfitPkr: 0,
    calendarTradingDays: 0,
    creditedLedgerDays: 0,
    isFromLedger: true,
    walletFallbackPkr: 0,
    isLoadingHistory: false,
  );
}

/// True when current PKT time is within PSX stock market hours.
bool isWithinPktMarketHours() => isStockMarketOpen();

double _round2(double v) => double.parse(v.toStringAsFixed(2));

/// Helper: extract profitPkr for a market key from raw map.
double _marketProfit(Map<dynamic, dynamic> raw, String key) {
  final m = raw[key];
  if (m is! Map) return 0.0;
  return (m["profitPkr"] as num?)?.toDouble() ?? 0.0;
}

/// Round to 2 decimal places.
double _r(double v) => double.parse(v.toStringAsFixed(2));

/// PKT date string from a UTC+5 wall-clock [pkt].
String pktDateStringFromPkt(DateTime pkt) =>
    "${pkt.year.toString().padLeft(4, "0")}-"
    "${pkt.month.toString().padLeft(2, "0")}-"
    "${pkt.day.toString().padLeft(2, "0")}";

String _pktDateString(DateTime pkt) => pktDateStringFromPkt(pkt);

FiveMarketLiveProfitState _buildState({
  required FiveMarketDailyResult? dailyResult,
  required FiveMarketConfig config,
  required TradingDayResult tradingDay,
  required Kmi30IndexTick? kmi30Tick,
  required Map<String, dynamic>? wallet,
}) {
  final basePkr =
      wallet != null ? investorAllocationBaseFromWallet(wallet) : 0.0;
  final isTradingDay = tradingDay.isTradingDay;
  final isStockOpen = isTradingDay && isStockMarketOpen();
  final isMarketHours = isStockOpen;
  final elapsedSec = isTradingDay ? elapsedStockSessionSeconds() : 0;
  final alloc = config.allocations;
  final rates = config.rates;

  final stockAlloc = basePkr * alloc.stock / 100;
  final techAlloc = basePkr * alloc.tech / 100;
  final debtAlloc = basePkr * alloc.debt / 100;
  final moneyAlloc = basePkr * alloc.money / 100;
  final goldAlloc = basePkr * alloc.gold / 100;

  if (!isTradingDay) {
    return FiveMarketLiveProfitState(
      basePkr: basePkr,
      isTradingDay: false,
      isMarketHours: false,
      stockProfitPkr: 0,
      techProfitPkr: 0,
      debtProfitPkr: 0,
      moneyProfitPkr: 0,
      goldProfitPkr: 0,
      totalProfitPkr: 0,
      stockAllocatedPkr: _round2(stockAlloc),
      techAllocatedPkr: _round2(techAlloc),
      debtAllocatedPkr: _round2(debtAlloc),
      moneyAllocatedPkr: _round2(moneyAlloc),
      goldAllocatedPkr: _round2(goldAlloc),
      kmi30ChangePercent: 0,
      goldChangePercent: dailyResult?.gold.changePercent ?? 0,
      techAnnualPercent: rates.techBenchmarkAnnualPercent,
      debtAnnualPercent: rates.debtAnnualPercent,
      moneyAnnualPercent: rates.moneyAnnualPercent,
      stockStatus: MarketSliceStatus.nonTradingDay,
      techStatus: MarketSliceStatus.nonTradingDay,
      debtStatus: MarketSliceStatus.nonTradingDay,
      moneyStatus: MarketSliceStatus.nonTradingDay,
      goldStatus: MarketSliceStatus.nonTradingDay,
    );
  }

  final kmi30Pct = isStockOpen ? (kmi30Tick?.changePercent ?? 0.0) : 0.0;
  final stockProfit = _round2(stockAlloc * kmi30Pct / 100);

  final techDaily = techAlloc * rates.techBenchmarkAnnualPercent / 100 / 365;
  final debtDaily = debtAlloc * rates.debtAnnualPercent / 100 / 365;
  final moneyDaily = moneyAlloc * rates.moneyAnnualPercent / 100 / 365;

  final techProfit = _round2(techDaily / 25200 * elapsedSec);
  final debtProfit = _round2(debtDaily / 25200 * elapsedSec);
  final moneyProfit = _round2(moneyDaily / 25200 * elapsedSec);

  final goldPct = dailyResult?.gold.changePercent ?? 0.0;
  final goldProfit = _round2(goldAlloc * goldPct / 100);

  final totalProfit = _round2(
    stockProfit + techProfit + debtProfit + moneyProfit + goldProfit,
  );

  final stockStatus = isTradingDay
      ? (isStockOpen ? MarketSliceStatus.live : MarketSliceStatus.realized)
      : MarketSliceStatus.nonTradingDay;

  final fixedStatus = stockStatus;

  final goldStatus = isTradingDay
      ? MarketSliceStatus.live
      : MarketSliceStatus.nonTradingDay;

  return FiveMarketLiveProfitState(
    basePkr: basePkr,
    isTradingDay: true,
    isMarketHours: isMarketHours,
    stockProfitPkr: stockProfit,
    techProfitPkr: techProfit,
    debtProfitPkr: debtProfit,
    moneyProfitPkr: moneyProfit,
    goldProfitPkr: goldProfit,
    totalProfitPkr: totalProfit,
    stockAllocatedPkr: _round2(stockAlloc),
    techAllocatedPkr: _round2(techAlloc),
    debtAllocatedPkr: _round2(debtAlloc),
    moneyAllocatedPkr: _round2(moneyAlloc),
    goldAllocatedPkr: _round2(goldAlloc),
    kmi30ChangePercent: kmi30Pct,
    goldChangePercent: goldPct,
    techAnnualPercent: rates.techBenchmarkAnnualPercent,
    debtAnnualPercent: rates.debtAnnualPercent,
    moneyAnnualPercent: rates.moneyAnnualPercent,
    stockStatus: stockStatus,
    techStatus: fixedStatus,
    debtStatus: fixedStatus,
    moneyStatus: fixedStatus,
    goldStatus: goldStatus,
  );
}

final fiveMarketLiveProfitProvider = StreamProvider<FiveMarketLiveProfitState>((
  ref,
) {
  final dailyResult = ref.watch(fiveMarketDailyResultProvider);
  final config =
      ref.watch(fiveMarketConfigProvider).valueOrNull ??
      FiveMarketConfig.defaults;
  final tradingDay = ref.watch(todayTradingDayProvider);
  final kmi30Tick = ref.watch(kmi30IndexTickProvider).valueOrNull;
  final wallet = ref.watch(userWalletStreamProvider).valueOrNull;

  final controller = StreamController<FiveMarketLiveProfitState>();

  void emit() {
    if (!controller.isClosed) {
      controller.add(
        _buildState(
          dailyResult: dailyResult,
          config: config,
          tradingDay: tradingDay,
          kmi30Tick: kmi30Tick,
          wallet: wallet,
        ),
      );
    }
  }

  emit();

  Timer? timer;
  if (tradingDay.isTradingDay) {
    timer = Timer.periodic(const Duration(minutes: 1), (_) => emit());
  }

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});

bool _useWalletFallback({required List<FiveMarketDailyLedgerDoc> periodDocs}) {
  // If no credited ledger docs exist for the period, always use wallet
  // fallback. Today's live data alone is NOT a valid monthly or yearly
  // total — it only represents today's intraday estimate. Monthly/Yearly
  // should only show ledger sums once the nightly credit job has run at
  // least once.
  return periodDocs.isEmpty;
}

/// Sums credited [five_market_daily] rows for the current PKT month + today's live.
final fiveMarketMonthlyProfitProvider = Provider<FiveMarketPeriodSummary>((
  ref,
) {
  final historyAsync = ref.watch(fiveMarketDailyHistoryProvider);
  final holidaysAsync = ref.watch(pkHolidaysProvider);
  final stillLoading = historyAsync.isLoading || holidaysAsync.isLoading;

  final history = historyAsync.valueOrNull ?? [];
  final holidays = holidaysAsync.valueOrNull ?? const <PkHoliday>[];
  final liveToday = ref.watch(fiveMarketLiveProfitProvider).valueOrNull;

  final nowPkt = DateTime.now().toUtc().add(const Duration(hours: 5));
  final currentMonth = nowPkt.month;
  final currentYear = nowPkt.year;
  final todayStr = _pktDateString(nowPkt);

  final periodStart = DateTime(currentYear, currentMonth, 1);
  final yesterday = DateTime(nowPkt.year, nowPkt.month, nowPkt.day)
      .subtract(const Duration(days: 1));
  final calendarDays = countElapsedCalendarTradingDays(
    periodStart: periodStart,
    periodEndInclusive: yesterday,
    holidays: holidays,
  );

  final monthDocs = history.where((doc) {
    if (doc.documentId == todayStr) return false;
    final dt = DateTime.tryParse(doc.documentId);
    if (dt == null) return false;
    return dt.month == currentMonth &&
        dt.year == currentYear &&
        doc.raw["creditedToWallet"] == true;
  }).toList();

  final creditedDays = monthDocs.length;

  if (stillLoading) {
    return FiveMarketPeriodSummary(
      label: "This Month",
      stockProfitPkr: 0,
      techProfitPkr: 0,
      debtProfitPkr: 0,
      moneyProfitPkr: 0,
      goldProfitPkr: 0,
      calendarTradingDays: calendarDays,
      creditedLedgerDays: creditedDays,
      isFromLedger: true,
      walletFallbackPkr: 0,
      isLoadingHistory: true,
    );
  }

  if (_useWalletFallback(periodDocs: monthDocs)) {
    // No credited ledger docs for this month yet.
    // Show PKR 0 — user has earned nothing this
    // month so far. Do NOT use all-time wallet
    // totalProfit as it includes prior months and
    // is misleading as a "This Month" figure.
    return FiveMarketPeriodSummary(
      label: "This Month",
      stockProfitPkr: 0,
      techProfitPkr: 0,
      debtProfitPkr: 0,
      moneyProfitPkr: 0,
      goldProfitPkr: 0,
      calendarTradingDays: calendarDays,
      creditedLedgerDays: creditedDays,
      isFromLedger: false,
      walletFallbackPkr: 0,
    );
  }

  var stockTotal = 0.0;
  var techTotal = 0.0;
  var debtTotal = 0.0;
  var moneyTotal = 0.0;
  var goldTotal = 0.0;

  for (final doc in monthDocs) {
    final markets = doc.raw["markets"] as Map? ?? {};
    stockTotal += _marketProfit(markets, "stock");
    techTotal += _marketProfit(markets, "tech");
    debtTotal += _marketProfit(markets, "debt");
    moneyTotal += _marketProfit(markets, "money");
    goldTotal += _marketProfit(markets, "gold");
  }

  // Add today's live estimate ONLY when we already have at least one
  // credited ledger day for this period.
  if (monthDocs.isNotEmpty && liveToday != null && liveToday.isTradingDay) {
    stockTotal += liveToday.stockProfitPkr;
    techTotal += liveToday.techProfitPkr;
    debtTotal += liveToday.debtProfitPkr;
    moneyTotal += liveToday.moneyProfitPkr;
    goldTotal += liveToday.goldProfitPkr;
  }

  return FiveMarketPeriodSummary(
    label: "This Month",
    stockProfitPkr: _r(stockTotal),
    techProfitPkr: _r(techTotal),
    debtProfitPkr: _r(debtTotal),
    moneyProfitPkr: _r(moneyTotal),
    goldProfitPkr: _r(goldTotal),
    calendarTradingDays: calendarDays,
    creditedLedgerDays: creditedDays,
    isFromLedger: true,
    walletFallbackPkr: 0,
  );
});

/// Sums credited [five_market_daily] rows for the current PKT year + today's live.
final fiveMarketYearlyProfitProvider = Provider<FiveMarketPeriodSummary>((ref) {
  final historyAsync = ref.watch(fiveMarketDailyHistoryProvider);
  final holidaysAsync = ref.watch(pkHolidaysProvider);
  final stillLoading = historyAsync.isLoading || holidaysAsync.isLoading;

  final history = historyAsync.valueOrNull ?? [];
  final holidays = holidaysAsync.valueOrNull ?? const <PkHoliday>[];
  final liveToday = ref.watch(fiveMarketLiveProfitProvider).valueOrNull;
  final wallet = ref.watch(userWalletStreamProvider).valueOrNull;

  final nowPkt = DateTime.now().toUtc().add(const Duration(hours: 5));
  final currentYear = nowPkt.year;
  final todayStr = _pktDateString(nowPkt);

  final periodStart = DateTime(currentYear, 1, 1);
  final yesterday = DateTime(nowPkt.year, nowPkt.month, nowPkt.day)
      .subtract(const Duration(days: 1));
  final calendarDays = countElapsedCalendarTradingDays(
    periodStart: periodStart,
    periodEndInclusive: yesterday,
    holidays: holidays,
  );

  final yearDocs = history.where((doc) {
    if (doc.documentId == todayStr) return false;
    final dt = DateTime.tryParse(doc.documentId);
    if (dt == null) return false;
    return dt.year == currentYear && doc.raw["creditedToWallet"] == true;
  }).toList();

  final creditedDays = yearDocs.length;

  if (stillLoading) {
    return FiveMarketPeriodSummary(
      label: "This Year",
      stockProfitPkr: 0,
      techProfitPkr: 0,
      debtProfitPkr: 0,
      moneyProfitPkr: 0,
      goldProfitPkr: 0,
      calendarTradingDays: calendarDays,
      creditedLedgerDays: creditedDays,
      isFromLedger: true,
      walletFallbackPkr: 0,
      isLoadingHistory: true,
    );
  }

  if (_useWalletFallback(periodDocs: yearDocs)) {
    final walletTotal = (wallet?["totalProfit"] as num?)?.toDouble() ?? 0.0;
    return FiveMarketPeriodSummary(
      label: "This Year",
      stockProfitPkr: 0,
      techProfitPkr: 0,
      debtProfitPkr: 0,
      moneyProfitPkr: 0,
      goldProfitPkr: 0,
      calendarTradingDays: calendarDays,
      creditedLedgerDays: creditedDays,
      isFromLedger: false,
      walletFallbackPkr: _r(walletTotal),
    );
  }

  var stockTotal = 0.0;
  var techTotal = 0.0;
  var debtTotal = 0.0;
  var moneyTotal = 0.0;
  var goldTotal = 0.0;

  for (final doc in yearDocs) {
    final markets = doc.raw["markets"] as Map? ?? {};
    stockTotal += _marketProfit(markets, "stock");
    techTotal += _marketProfit(markets, "tech");
    debtTotal += _marketProfit(markets, "debt");
    moneyTotal += _marketProfit(markets, "money");
    goldTotal += _marketProfit(markets, "gold");
  }

  // Add today's live estimate ONLY when we already have at least one
  // credited ledger day for this period.
  if (yearDocs.isNotEmpty && liveToday != null && liveToday.isTradingDay) {
    stockTotal += liveToday.stockProfitPkr;
    techTotal += liveToday.techProfitPkr;
    debtTotal += liveToday.debtProfitPkr;
    moneyTotal += liveToday.moneyProfitPkr;
    goldTotal += liveToday.goldProfitPkr;
  }

  return FiveMarketPeriodSummary(
    label: "This Year",
    stockProfitPkr: _r(stockTotal),
    techProfitPkr: _r(techTotal),
    debtProfitPkr: _r(debtTotal),
    moneyProfitPkr: _r(moneyTotal),
    goldProfitPkr: _r(goldTotal),
    calendarTradingDays: calendarDays,
    creditedLedgerDays: creditedDays,
    isFromLedger: true,
    walletFallbackPkr: 0,
  );
});
