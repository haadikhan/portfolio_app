import "package:cloud_functions/cloud_functions.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../features/investment/domain/five_market_models.dart";
import "../../providers/auth_providers.dart";
import "../services/five_market_admin_service.dart";

final fiveMarketAdminServiceProvider = Provider<FiveMarketAdminService>((ref) {
  return FiveMarketAdminService(
    FirebaseFunctions.instanceFor(region: "us-central1"),
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

/// PKT wall calendar date `yyyy-MM-dd` (UTC+5, no DST).
String adminTodayPktDateString() {
  final pktWall = DateTime.now().toUtc().add(const Duration(hours: 5));
  return DateFormat("yyyy-MM-dd").format(pktWall);
}
