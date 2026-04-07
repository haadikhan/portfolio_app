import "package:cloud_firestore/cloud_firestore.dart";

import "../models/market_company.dart";
import "../models/market_daily_bar.dart";

class MarketDataService {
  MarketDataService(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _companies =>
      _db.collection("market_companies");

  Stream<List<MarketCompany>> watchCompanies({bool activeOnly = true}) {
    Query<Map<String, dynamic>> q = _companies.orderBy("name");
    if (activeOnly) {
      q = q.where("isActive", isEqualTo: true);
    }
    return q.snapshots().map((s) {
      return s.docs.map((d) => MarketCompany.fromMap(d.id, d.data())).toList();
    });
  }

  Future<void> upsertCompany({
    String? companyId,
    required String name,
    required String ticker,
    required String exchange,
    required bool isActive,
    required String actorUid,
  }) async {
    final now = FieldValue.serverTimestamp();
    final doc = companyId == null || companyId.isEmpty
        ? _companies.doc()
        : _companies.doc(companyId);

    await doc.set({
      "name": name.trim(),
      "ticker": ticker.trim().toUpperCase(),
      "exchange": exchange.trim().toUpperCase(),
      "isActive": isActive,
      "updatedAt": now,
      "createdBy": actorUid,
      if (companyId == null || companyId.isEmpty) "createdAt": now,
    }, SetOptions(merge: true));
  }

  Stream<List<MarketDailyBar>> watchDailyBars(
    String companyId, {
    int limit = 120,
  }) {
    return _companies
        .doc(companyId)
        .collection("daily_bars")
        .orderBy("date", descending: false)
        .limit(limit)
        .snapshots()
        .map((s) {
      return s.docs.map((d) => MarketDailyBar.fromMap(d.id, d.data())).toList();
    });
  }

  Future<void> upsertDailyBar({
    required String companyId,
    required DateTime date,
    required double open,
    required double close,
    double? high,
    double? low,
    double? volume,
    String source = "manual",
    String? updatedBy,
  }) async {
    final key = _dateId(date);
    await _companies.doc(companyId).collection("daily_bars").doc(key).set({
      "date": Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      "open": open,
      "close": close,
      if (high != null) "high": high,
      if (low != null) "low": low,
      if (volume != null) "volume": volume,
      "source": source,
      "updatedAt": FieldValue.serverTimestamp(),
      if (updatedBy != null && updatedBy.isNotEmpty) "updatedBy": updatedBy,
    }, SetOptions(merge: true));
  }

  String _dateId(DateTime d) {
    final y = d.year.toString().padLeft(4, "0");
    final m = d.month.toString().padLeft(2, "0");
    final day = d.day.toString().padLeft(2, "0");
    return "$y-$m-$day";
  }
}
