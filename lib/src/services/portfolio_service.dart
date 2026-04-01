import "package:cloud_firestore/cloud_firestore.dart";

import "../models/portfolio_model.dart";
import "../models/return_history_model.dart";

class PortfolioService {
  PortfolioService(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _portfolios =>
      _db.collection("portfolios");

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _db.collection("transactions");

  // ── Investor reads ────────────────────────────────────────────────────────

  Stream<PortfolioModel?> streamPortfolio(String uid) {
    return _portfolios.doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return PortfolioModel.fromMap(snap.id, snap.data()!);
    });
  }

  Stream<List<ReturnHistoryModel>> streamReturnHistory(String uid) {
    return _portfolios
        .doc(uid)
        .collection("returnHistory")
        .orderBy("appliedAt", descending: true)
        .limit(12)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReturnHistoryModel.fromMap(d.id, d.data()))
            .toList());
  }

  // ── Admin reads ───────────────────────────────────────────────────────────

  Future<List<PortfolioModel>> fetchAllPortfolios() async {
    final snap = await _portfolios.get();
    return snap.docs
        .map((d) => PortfolioModel.fromMap(d.id, d.data()))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    final snap = await _db.collection("users").get();
    return snap.docs.map((d) => {"id": d.id, ...d.data()}).toList();
  }

  // ── Admin writes ──────────────────────────────────────────────────────────

  /// Apply a percentage return to a single user's portfolio.
  /// Returns the profit amount applied, or throws on failure.
  Future<double> applyReturnToUser({
    required String uid,
    required double returnPct,
    required String adminUid,
    required String mode,
    double? manualProfitAmount,
  }) async {
    final snap = await _portfolios.doc(uid).get();
    if (!snap.exists || snap.data() == null) {
      throw Exception("No portfolio found for user $uid");
    }
    final portfolio = PortfolioModel.fromMap(snap.id, snap.data()!);
    final previousValue = portfolio.currentValue;

    final profit = manualProfitAmount ?? (previousValue * returnPct / 100);
    final newValue = previousValue + profit;
    final effectivePct =
        manualProfitAmount != null && previousValue > 0
            ? (manualProfitAmount / previousValue) * 100
            : returnPct;

    final now = FieldValue.serverTimestamp();
    final batch = _db.batch();

    // Update portfolio doc
    batch.update(_portfolios.doc(uid), {
      "currentValue": newValue,
      "lastMonthlyReturnPct": effectivePct,
      "lastUpdated": now,
    });

    // Write returnHistory entry
    final histRef = _portfolios.doc(uid).collection("returnHistory").doc();
    batch.set(histRef, {
      "returnPct": effectivePct,
      "profitAmount": profit,
      "previousValue": previousValue,
      "newValue": newValue,
      "appliedAt": now,
      "appliedBy": adminUid,
      "mode": mode,
    });

    // Write profit_entry transaction (matching existing schema)
    final txRef = _transactions.doc();
    batch.set(txRef, {
      "userId": uid,
      "type": "profit_entry",
      "amount": profit,
      "status": "approved",
      "createdAt": now,
      "notes": "Monthly return ${effectivePct.toStringAsFixed(2)}% applied by admin",
    });

    await batch.commit();
    return profit;
  }

  /// Apply percentage return to ALL users who have a portfolio document.
  /// Returns a summary: {successCount, failCount, totalProfit, errors}
  Future<Map<String, dynamic>> applyPercentageToAll({
    required double returnPct,
    required String adminUid,
  }) async {
    final portfolios = await fetchAllPortfolios();
    int successCount = 0;
    int failCount = 0;
    double totalProfit = 0;
    final List<String> errors = [];

    for (final portfolio in portfolios) {
      try {
        final profit = await applyReturnToUser(
          uid: portfolio.uid,
          returnPct: returnPct,
          adminUid: adminUid,
          mode: "percentage",
        );
        totalProfit += profit;
        successCount++;
      } catch (e) {
        failCount++;
        errors.add("${portfolio.uid}: $e");
      }
    }

    return {
      "successCount": successCount,
      "failCount": failCount,
      "totalProfit": totalProfit,
      "errors": errors,
    };
  }
}
