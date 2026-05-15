import "package:cloud_functions/cloud_functions.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../features/investment/domain/five_market_models.dart";
import "../../providers/auth_providers.dart";
import "../services/five_market_admin_service.dart";

final fiveMarketAdminServiceProvider = Provider<FiveMarketAdminService>((ref) {
  return FiveMarketAdminService(
    FirebaseFunctions.instanceFor(region: "us-central1"),
    ref.read(firebaseFirestoreProvider),
  );
});

/// Streams `settings/five_market_calc` for the admin config tab.
final adminFiveMarketConfigProvider = StreamProvider<FiveMarketConfig>((ref) {
  return ref
      .watch(firebaseFirestoreProvider)
      .collection("settings")
      .doc("five_market_calc")
      .snapshots()
      .map((snap) {
        if (snap.exists && snap.data() != null) {
          return FiveMarketConfig.fromFirestore(snap.data()!);
        }
        return FiveMarketConfig.defaults;
      });
});

/// Pakistan public holidays from `settings/pakistan_holidays`.
final adminPkHolidaysProvider = StreamProvider<List<PkHoliday>>((ref) {
  return ref
      .watch(firebaseFirestoreProvider)
      .collection("settings")
      .doc("pakistan_holidays")
      .snapshots()
      .map((snap) {
        if (!snap.exists || snap.data() == null) return <PkHoliday>[];
        final raw = snap.data()!["holidays"];
        if (raw is! List) return <PkHoliday>[];
        final list = raw
            .whereType<Map>()
            .map((m) => PkHoliday.fromMap(m.cast<String, dynamic>()))
            .where((h) => h.date.isNotEmpty)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        return list;
      });
});

/// Recent day overrides (newest first).
final adminFiveMarketDayOverridesProvider =
    StreamProvider<List<FiveMarketDayOverride>>((ref) {
  return ref
      .watch(firebaseFirestoreProvider)
      .collection("settings")
      .doc("five_market")
      .collection("five_market_day_overrides")
      .orderBy("date", descending: true)
      .limit(50)
      .snapshots()
      .map((snap) {
        return snap.docs
            .map((d) => FiveMarketDayOverride.fromFirestore(d.data()))
            .toList();
      });
});

/// Last 30 EOD snapshots (`investment_daily_market_close`), newest first.
final adminEodSnapshotsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref
      .watch(firebaseFirestoreProvider)
      .collection("investment_daily_market_close")
      .orderBy("date", descending: true)
      .limit(30)
      .snapshots()
      .map((snap) {
        return snap.docs.map((d) {
          return <String, dynamic>{
            "id": d.id,
            ...d.data(),
          };
        }).toList();
      });
});

/// `userId` → opted in to five-market daily ledger.
final adminPortfolioLedgerMapProvider =
    StreamProvider<Map<String, bool>>((ref) {
  return ref
      .watch(firebaseFirestoreProvider)
      .collection("portfolios")
      .where("fiveMarketDailyLedger", isEqualTo: true)
      .snapshots()
      .map((snap) {
        return {for (final d in snap.docs) d.id: true};
      });
});

/// PKT wall calendar date `yyyy-MM-dd` (UTC+5, no DST).
String adminTodayPktDateString() {
  final pktWall = DateTime.now().toUtc().add(const Duration(hours: 5));
  return DateFormat("yyyy-MM-dd").format(pktWall);
}
