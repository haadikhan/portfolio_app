import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "package:portfolio_app/src/features/investment/data/allocation_money_market.dart";
import "package:portfolio_app/src/features/investment/domain/market_sleeve_balance.dart";
import "package:portfolio_app/src/features/investment/providers/five_market_providers.dart";
import "package:portfolio_app/src/providers/auth_providers.dart";
import "package:portfolio_app/src/providers/wallet_providers.dart";

/// One Firestore row under `portfolios/{uid}/five_market_daily/{yyyy-MM-dd}`.
@immutable
class FiveMarketDailyLedgerDoc {
  const FiveMarketDailyLedgerDoc({
    required this.documentId,
    required this.raw,
  });

  final String documentId;
  final Map<String, dynamic> raw;

  bool get creditedToWallet => raw["creditedToWallet"] == true;
}

/// PKT `yyyy-MM-dd` (no DST).
String todayPktDateString() {
  final pktWall = DateTime.now().toUtc().add(const Duration(hours: 5));
  return DateFormat("yyyy-MM-dd").format(pktWall);
}

/// Recent daily ledger rows (newest document IDs first).
final fiveMarketDailyHistoryProvider =
    StreamProvider<List<FiveMarketDailyLedgerDoc>>((ref) {
  return authBoundFirestoreStream(
    ref,
    whenSignedOut: const <FiveMarketDailyLedgerDoc>[],
    body: (user) => ref
        .read(firebaseFirestoreProvider)
        .collection("portfolios")
        .doc(user.uid)
        .collection("five_market_daily")
        .orderBy(FieldPath.documentId, descending: true)
        .limit(150)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) =>
                    FiveMarketDailyLedgerDoc(documentId: d.id, raw: d.data()),
              )
              .toList(),
        ),
  );
});

/// Builds [SleeveBalanceSnapshot] for dashboard / portfolio / daily markets UI.
final marketSleeveBalancesProvider = Provider<SleeveBalanceSnapshot?>((ref) {
  final wallet = ref.watch(userWalletStreamProvider).valueOrNull;
  final config = ref.watch(fiveMarketConfigProvider).valueOrNull;
  final history = ref.watch(fiveMarketDailyHistoryProvider).valueOrNull ??
      const <FiveMarketDailyLedgerDoc>[];
  final todayResult = ref.watch(fiveMarketDailyResultProvider);

  if (wallet == null || config == null) return null;

  final todayId = todayPktDateString();
  FiveMarketDailyLedgerDoc? todayRow;
  for (final r in history) {
    if (r.documentId == todayId) {
      todayRow = r;
      break;
    }
  }
  final todayCredited = todayDocCredited(todayRow?.raw);

  final creditedDocs = history
      .where((r) => r.creditedToWallet)
      .map((r) => r.raw)
      .toList();
  final creditedBySleeve = sumCreditedProfitsBySleeve(creditedDocs);

  final allocationTotal = allocationTotalFromWallet(wallet);
  final mmBase = moneyMarketAvailableFromWallet(wallet);
  final tp = (wallet["totalProfit"] as num?)?.toDouble() ?? 0.0;

  return buildSleeveBalanceSnapshot(
    allocationTotalPkr: allocationTotal,
    creditedWalletProfitPkr: tp,
    moneyMarketBasePkr: mmBase,
    allocations: config.allocations,
    creditedBySleeve: creditedBySleeve,
    todayResult: todayResult,
    todayCreditedToWallet: todayCredited,
  );
});
