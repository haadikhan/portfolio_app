import "package:cloud_firestore/cloud_firestore.dart";

import "../models/admin_investor_models.dart";

class AdminInvestorService {
  AdminInvestorService(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection("users");
  CollectionReference<Map<String, dynamic>> get _wallets =>
      _db.collection("wallets");
  CollectionReference<Map<String, dynamic>> get _transactions =>
      _db.collection("transactions");
  CollectionReference<Map<String, dynamic>> get _kyc => _db.collection("kyc");

  Future<List<AdminInvestorSummary>> fetchInvestors() async {
    final usersSnap = await _users.get();
    final byId = <String, AdminInvestorSummary>{};

    for (final doc in usersSnap.docs) {
      final summary = AdminInvestorSummary.fromFirestore(doc.id, doc.data());
      final role = summary.role.toLowerCase();
      if (role == "admin" || role == "team") continue;
      byId[summary.userId] = summary;
    }

    // Backfill investor IDs from transaction and KYC docs for cases where
    // `users/{uid}` is missing or incomplete.
    final txSnap = await _transactions.get();
    for (final doc in txSnap.docs) {
      final uid = (doc.data()["userId"] as String? ?? "").trim();
      if (uid.isNotEmpty && !byId.containsKey(uid)) {
        byId[uid] = AdminInvestorSummary(
          userId: uid,
          name: "",
          email: "",
          phone: "",
          kycStatus: "pending",
          createdAt: null,
          role: "investor",
        );
      }
    }

    final kycSnap = await _kyc.get();
    for (final doc in kycSnap.docs) {
      final uid = doc.id.trim();
      if (uid.isNotEmpty && !byId.containsKey(uid)) {
        final kycStatus = (doc.data()["status"] as String? ?? "pending").trim();
        byId[uid] = AdminInvestorSummary(
          userId: uid,
          name: "",
          email: "",
          phone: "",
          kycStatus: kycStatus,
          createdAt: null,
          role: "investor",
        );
      }
    }

    final list = byId.values.toList();
    list.sort((a, b) {
      final an = a.name.isEmpty ? a.email : a.name;
      final bn = b.name.isEmpty ? b.email : b.name;
      return an.toLowerCase().compareTo(bn.toLowerCase());
    });
    return list;
  }

  Future<AdminInvestorDetail?> fetchInvestorDetail(String userId) async {
    final userDoc = await _users.doc(userId).get();
    final summary = userDoc.exists && userDoc.data() != null
        ? AdminInvestorSummary.fromFirestore(userDoc.id, userDoc.data()!)
        : AdminInvestorSummary(
            userId: userId,
            name: "",
            email: "",
            phone: "",
            kycStatus: "pending",
            createdAt: null,
            role: "investor",
          );

    final walletDoc = await _wallets.doc(userId).get();
    final wallet = walletDoc.exists && walletDoc.data() != null
        ? AdminInvestorWalletSnapshot.fromFirestore(walletDoc.data()!)
        : AdminInvestorWalletSnapshot.empty;

    final txSnap = await _transactions.where("userId", isEqualTo: userId).get();
    final transactions = txSnap.docs
        .map((doc) => AdminInvestorTransaction.fromFirestore(doc.id, doc.data()))
        .toList()
      ..sort((a, b) {
        final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });

    return AdminInvestorDetail(
      summary: summary,
      wallet: wallet,
      transactions: transactions,
    );
  }
}
