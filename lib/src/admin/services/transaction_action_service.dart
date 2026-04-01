import "package:cloud_firestore/cloud_firestore.dart";
import "package:cloud_functions/cloud_functions.dart";

/// All admin writes to [transactions] and [users] go through Cloud Functions
/// so the Admin SDK bypasses Firestore security rules.
///
/// [adminApproveTransaction] — approves a pending transaction, updates user
///   balance (deposit → +amount, withdrawal → -amount), recalculates wallet.
///
/// [adminRejectTransaction] — rejects a pending transaction, adds rejection
///   note, recalculates wallet (frees reserved amounts).
class TransactionActionService {
  TransactionActionService(this._db);

  final FirebaseFirestore _db;
  final FirebaseFunctions _fn =
      FirebaseFunctions.instanceFor(region: "us-central1");

  // ── Approve ───────────────────────────────────────────────────────────────

  Future<void> approveTransaction({
    required String txnId,
    // These params are kept for API compatibility but the logic is server-side
    required String txnType,
    required double amount,
    required String userId,
    required String adminUid,
  }) async {
    await _fn
        .httpsCallable("adminApproveTransaction")
        .call({"txnId": txnId});
  }

  // ── Reject ────────────────────────────────────────────────────────────────

  Future<void> rejectTransaction({
    required String txnId,
    required String adminUid,
    String? rejectionNote,
    String? userId,
  }) async {
    await _fn.httpsCallable("adminRejectTransaction").call({
      "txnId": txnId,
      "rejectionNote": rejectionNote ?? "",
    });
  }

  // ── Real-time streams ─────────────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTransactionsByType(
      String type) {
    return _db
        .collection("transactions")
        .where("type", isEqualTo: type)
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  // ── Overview aggregation ──────────────────────────────────────────────────

  Stream<Map<String, dynamic>> watchOverviewStats() {
    return _db.collection("transactions").snapshots().map((snap) {
      int pendingDeposits = 0;
      int pendingWithdrawals = 0;
      double totalDeposited = 0;
      double totalWithdrawn = 0;
      double totalProfit = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final type = (data["type"] as String? ?? "").toLowerCase();
        final status = (data["status"] as String? ?? "").toLowerCase();
        final amount = (data["amount"] as num?)?.toDouble() ?? 0;

        if (type == "deposit" && status == "pending") pendingDeposits++;
        if (type == "withdrawal" && status == "pending") pendingWithdrawals++;
        if (type == "deposit" && status == "approved") totalDeposited += amount;
        if (type == "withdrawal" && status == "approved") totalWithdrawn += amount;
        if ((type == "profit_entry" || type == "profit") && status == "approved") {
          totalProfit += amount;
        }
      }

      return {
        "pendingDeposits": pendingDeposits,
        "pendingWithdrawals": pendingWithdrawals,
        "totalDeposited": totalDeposited,
        "totalWithdrawn": totalWithdrawn,
        "totalProfit": totalProfit,
        // Derived platform-wide net balance
        "platformBalance": totalDeposited - totalWithdrawn + totalProfit,
      };
    });
  }
}
