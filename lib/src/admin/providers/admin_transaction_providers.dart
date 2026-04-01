import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../providers/auth_providers.dart";
import "../services/transaction_action_service.dart";

// ── Service provider ─────────────────────────────────────────────────────────

final transactionActionServiceProvider =
    Provider<TransactionActionService>((ref) {
  return TransactionActionService(ref.read(firebaseFirestoreProvider));
});

// ── Real-time stream providers ────────────────────────────────────────────────

/// All deposits ordered by createdAt desc (real-time).
final allDepositsProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
  return ref
      .read(transactionActionServiceProvider)
      .watchTransactionsByType("deposit");
});

/// All withdrawals ordered by createdAt desc (real-time).
final allWithdrawalsProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
  return ref
      .read(transactionActionServiceProvider)
      .watchTransactionsByType("withdrawal");
});

/// Aggregated overview stats derived from the full transactions stream.
final adminOverviewStatsProvider =
    StreamProvider<Map<String, dynamic>>((ref) {
  return ref
      .read(transactionActionServiceProvider)
      .watchOverviewStats();
});

// ── Action notifier ───────────────────────────────────────────────────────────

class TransactionActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  TransactionActionService get _service =>
      ref.read(transactionActionServiceProvider);

  String get _adminUid =>
      ref.read(firebaseAuthProvider).currentUser?.uid ?? "unknown_admin";

  Future<void> approve({
    required String txnId,
    required String txnType,
    required double amount,
    required String userId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _service.approveTransaction(
        txnId: txnId,
        txnType: txnType,
        amount: amount,
        userId: userId,
        adminUid: _adminUid,
      );
    });
  }

  Future<void> reject({
    required String txnId,
    String? rejectionNote,
    String? userId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _service.rejectTransaction(
        txnId: txnId,
        adminUid: _adminUid,
        rejectionNote: rejectionNote,
        userId: userId,
      );
    });
  }
}

final transactionActionProvider =
    AsyncNotifierProvider<TransactionActionNotifier, void>(
  TransactionActionNotifier.new,
);

