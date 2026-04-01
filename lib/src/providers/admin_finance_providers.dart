import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "auth_providers.dart";

/// Pending deposit requests (newest first). Requires admin Firestore reads.
final adminPendingDepositsStreamProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
  ref.watch(currentUserProvider);
  return ref
      .read(firebaseFirestoreProvider)
      .collection("deposit_requests")
      .where("status", isEqualTo: "pending")
      .orderBy("createdAt", descending: true)
      .limit(50)
      .snapshots();
});

/// Reviewed deposits (approved/rejected).
final adminReviewedDepositsStreamProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
  ref.watch(currentUserProvider);
  return ref
      .read(firebaseFirestoreProvider)
      .collection("deposit_requests")
      .where("status", whereIn: ["approved", "rejected"])
      .orderBy("updatedAt", descending: true)
      .limit(50)
      .snapshots();
});

/// Pending withdrawal requests.
final adminPendingWithdrawalsStreamProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
  ref.watch(currentUserProvider);
  return ref
      .read(firebaseFirestoreProvider)
      .collection("withdrawal_requests")
      .where("status", isEqualTo: "pending")
      .orderBy("createdAt", descending: true)
      .limit(50)
      .snapshots();
});

/// Approved withdrawals awaiting settlement (`completeWithdrawal`).
final adminApprovedWithdrawalsStreamProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
  ref.watch(currentUserProvider);
  return ref
      .read(firebaseFirestoreProvider)
      .collection("withdrawal_requests")
      .where("status", isEqualTo: "approved")
      .orderBy("createdAt", descending: true)
      .limit(30)
      .snapshots();
});

/// Closed withdrawals (completed/cancelled).
final adminClosedWithdrawalsStreamProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
  ref.watch(currentUserProvider);
  return ref
      .read(firebaseFirestoreProvider)
      .collection("withdrawal_requests")
      .where("status", whereIn: ["completed", "cancelled"])
      .orderBy("updatedAt", descending: true)
      .limit(50)
      .snapshots();
});

/// Recent ledger rows (admin visibility).
final adminRecentTransactionsStreamProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
  ref.watch(currentUserProvider);
  return ref
      .read(firebaseFirestoreProvider)
      .collection("transactions")
      .orderBy("createdAt", descending: true)
      .limit(100)
      .snapshots();
});

/// Audit trail for admin financial actions.
final adminAuditLogsStreamProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
  ref.watch(currentUserProvider);
  return ref
      .read(firebaseFirestoreProvider)
      .collection("audit_logs")
      .orderBy("createdAt", descending: true)
      .limit(100)
      .snapshots();
});
