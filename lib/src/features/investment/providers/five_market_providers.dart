import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "package:portfolio_app/src/features/investment/data/allocation_money_market.dart";
import "package:portfolio_app/src/features/investment/domain/five_market_daily_engine.dart";
import "package:portfolio_app/src/features/investment/domain/five_market_models.dart";
import "package:portfolio_app/src/features/market/presentation/providers/kmi30_companies_providers.dart";
import "package:portfolio_app/src/features/market/providers/kmi30_index_provider.dart";
import "package:portfolio_app/src/providers/auth_providers.dart";
import "package:portfolio_app/src/providers/wallet_providers.dart";

/// Streams `settings/five_market_calc` → [FiveMarketConfig].
final fiveMarketConfigProvider = StreamProvider<FiveMarketConfig>((ref) {
  return authBoundFirestoreStream<FiveMarketConfig>(
    ref,
    whenSignedOut: FiveMarketConfig.defaults,
    body: (_) => ref
        .read(firebaseFirestoreProvider)
        .collection("settings")
        .doc("five_market_calc")
        .snapshots()
        .map((s) {
          if (s.exists && s.data() != null) {
            return FiveMarketConfig.fromFirestore(s.data()!);
          }
          return FiveMarketConfig.defaults;
        }),
  );
});

/// Streams `settings/pakistan_holidays` → list of [PkHoliday].
final pkHolidaysProvider = StreamProvider<List<PkHoliday>>((ref) {
  return authBoundFirestoreStream<List<PkHoliday>>(
    ref,
    whenSignedOut: const [],
    body: (_) => ref
        .read(firebaseFirestoreProvider)
        .collection("settings")
        .doc("pakistan_holidays")
        .snapshots()
        .map((s) {
          if (!s.exists || s.data() == null) return <PkHoliday>[];
          final raw = s.data()!["holidays"];
          if (raw is! List) return <PkHoliday>[];
          return raw
              .whereType<Map>()
              .map((m) => PkHoliday.fromMap(m.cast<String, dynamic>()))
              .toList();
        }),
  );
});

/// Streams today's admin day override (or null if none). Document ID = PKT `yyyy-MM-dd`.
final todayOverrideProvider = StreamProvider<FiveMarketDayOverride?>((ref) {
  final todayPkt = _todayPkt();
  return authBoundFirestoreStream<FiveMarketDayOverride?>(
    ref,
    whenSignedOut: null,
    body: (_) => ref
        .read(firebaseFirestoreProvider)
        .collection("settings")
        .doc("five_market")
        .collection("five_market_day_overrides")
        .doc(todayPkt)
        .snapshots()
        .map((s) {
          if (s.exists && s.data() != null) {
            return FiveMarketDayOverride.fromFirestore(s.data()!);
          }
          return null;
        }),
  );
});

/// Resolved trading day for today (PKT wall date, UTC+5 civil calendar).
final todayTradingDayProvider = Provider<TradingDayResult>((ref) {
  final holidays = ref.watch(pkHolidaysProvider).valueOrNull ?? const [];
  final override = ref.watch(todayOverrideProvider).valueOrNull;
  return FiveMarketDailyEngine.resolveTradingDay(
    datePkt: _todayPkt(),
    holidays: holidays,
    override: override,
  );
});

/// Latest EOD snapshot map (`investment_daily_market_close`), most recent by `date`.
final latestEodSnapshotProvider =
    StreamProvider<Map<String, dynamic>?>((ref) {
  return authBoundFirestoreStream<Map<String, dynamic>?>(
    ref,
    whenSignedOut: null,
    body: (_) => ref
        .read(firebaseFirestoreProvider)
        .collection("investment_daily_market_close")
        .orderBy("date", descending: true)
        .limit(1)
        .snapshots()
        .map((q) => q.docs.isNotEmpty ? q.docs.first.data() : null),
  );
});

/// Five-market daily result for today (live inputs: KMI30 index + gold quote).
final fiveMarketDailyResultProvider = Provider<FiveMarketDailyResult?>((ref) {
  final config = ref.watch(fiveMarketConfigProvider).valueOrNull;
  final tradingDay = ref.watch(todayTradingDayProvider);
  final kmi30Tick = ref.watch(kmi30IndexTickProvider).valueOrNull;
  final goldQuote = ref.watch(goldPriceStreamProvider).valueOrNull;
  final wallet = ref.watch(userWalletStreamProvider).valueOrNull;

  if (config == null || wallet == null) {
    return null;
  }

  final basePkr = allocationTotalFromWallet(wallet);
  final kmi30Pct = kmi30Tick?.changePercent ?? 0.0;
  final goldPct = goldQuote?.changePercent ?? 0.0;

  // LIVE only during market hours (09:00–16:00 PKT) on trading days
  // REALIZED after 16:00 PKT on trading days
  final isIntraday = tradingDay.isTradingDay && _isWithinMarketHours();

  return FiveMarketDailyEngine.calculate(
    basePkr: basePkr,
    config: config,
    tradingDay: tradingDay,
    kmi30Percent: kmi30Pct,
    goldPercent: goldPct,
    isIntraday: isIntraday,
  );
});

/// PKT calendar date string `yyyy-MM-dd` (Pakistan has no DST; fixed UTC+5 offset).
String _todayPkt() {
  final pktWall = DateTime.now().toUtc().add(const Duration(hours: 5));
  return DateFormat("yyyy-MM-dd").format(pktWall);
}

/// Returns current hour in PKT (Asia/Karachi, UTC+5).
int _currentPktHour() {
  return DateTime.now().toUtc().add(const Duration(hours: 5)).hour;
}

/// True when current PKT time is within PSX market hours (09:00–16:00).
bool _isWithinMarketHours() {
  final hour = _currentPktHour();
  return hour >= 9 && hour < 16;
}
