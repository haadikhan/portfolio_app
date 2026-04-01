import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/portfolio_model.dart";
import "../models/return_history_model.dart";
import "auth_providers.dart";

// ── Dashboard stats (computed from transactions + portfolio) ──────────────────

class DashboardStats {
  const DashboardStats({
    this.totalDeposited = 0,
    this.totalWithdrawn = 0,
    this.totalProfit = 0,
    this.currentValue = 0,
    this.profitLoss = 0,
    this.returnPct,
    this.portfolio,
  });

  final double totalDeposited;
  final double totalWithdrawn;
  final double totalProfit;

  /// Portfolio currentValue if portfolio doc exists, else falls back to ledger balance.
  final double currentValue;

  /// currentValue - totalDeposited
  final double profitLoss;

  /// null means no deposits yet (avoid division by zero).
  final double? returnPct;

  /// Raw portfolio doc (may be null if not set up yet).
  final PortfolioModel? portfolio;
}

/// Streams aggregated dashboard stats for the signed-in user.
final dashboardStatsProvider = StreamProvider<DashboardStats>((ref) async* {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    yield const DashboardStats();
    return;
  }

  final db = ref.read(firebaseFirestoreProvider);

    // Stream transactions; fetch portfolio doc on each update
  final txnStream = db
      .collection("transactions")
      .where("userId", isEqualTo: uid)
      .snapshots();

  // Merge both streams by listening to them reactively
  await for (final txnSnap in txnStream) {
    // Compute ledger values from transactions
    double totalDeposited = 0;
    double totalWithdrawn = 0;
    double totalProfit = 0;

    for (final doc in txnSnap.docs) {
      final d = doc.data();
      final status = (d["status"] as String? ?? "").toLowerCase();
      if (status != "approved") continue;
      final type = (d["type"] as String? ?? "").toLowerCase();
      final amount = (d["amount"] as num?)?.toDouble() ?? 0;
      if (type == "deposit") {
        totalDeposited += amount;
      } else if (type == "withdrawal") {
        totalWithdrawn += amount;
      } else if (type == "profit_entry" || type == "profit") {
        totalProfit += amount;
      }
    }

    // Try to read portfolio doc synchronously (one-shot)
    PortfolioModel? portfolio;
    try {
      final pDoc = await db.collection("portfolios").doc(uid).get();
      if (pDoc.exists && pDoc.data() != null) {
        portfolio = PortfolioModel.fromMap(uid, pDoc.data()!);
      }
    } catch (_) {}

    final ledgerBalance = totalDeposited - totalWithdrawn + totalProfit;
    final currentValue =
        portfolio != null ? portfolio.currentValue : ledgerBalance;
    final profitLoss = currentValue - totalDeposited;
    final returnPct =
        totalDeposited > 0 ? (profitLoss / totalDeposited) * 100 : null;

    yield DashboardStats(
      totalDeposited: totalDeposited,
      totalWithdrawn: totalWithdrawn,
      totalProfit: totalProfit,
      currentValue: currentValue,
      profitLoss: profitLoss,
      returnPct: returnPct,
      portfolio: portfolio,
    );
  }
});

/// Convenience: streams all returnHistory entries for the chart (ascending).
final returnHistoryForChartProvider =
    StreamProvider<List<ReturnHistoryModel>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value([]);
  return ref
      .read(firebaseFirestoreProvider)
      .collection("portfolios")
      .doc(uid)
      .collection("returnHistory")
      .orderBy("appliedAt", descending: false)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => ReturnHistoryModel.fromMap(d.id, d.data()))
          .toList());
});
