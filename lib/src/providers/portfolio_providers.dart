import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/portfolio_model.dart";
import "../models/return_history_model.dart";
import "../services/portfolio_service.dart";
import "auth_providers.dart";

// ── Service provider ─────────────────────────────────────────────────────────

final portfolioServiceProvider = Provider<PortfolioService>((ref) {
  return PortfolioService(ref.read(firebaseFirestoreProvider));
});

// ── Investor stream providers ─────────────────────────────────────────────────

/// Live stream of portfolios/{uid} for a given user.
final portfolioProvider =
    StreamProvider.family<PortfolioModel?, String>((ref, uid) {
  return ref.read(portfolioServiceProvider).streamPortfolio(uid);
});

/// Live stream of portfolios/{uid}/returnHistory (newest first, limit 12).
final returnHistoryProvider =
    StreamProvider.family<List<ReturnHistoryModel>, String>((ref, uid) {
  return ref.read(portfolioServiceProvider).streamReturnHistory(uid);
});

// ── Admin fetch providers ────────────────────────────────────────────────────

/// Fetches all portfolios/ documents (admin only — called on demand).
final allPortfoliosProvider = FutureProvider<List<PortfolioModel>>((ref) {
  return ref.read(portfolioServiceProvider).fetchAllPortfolios();
});

/// Fetches all users/ documents for admin manual-mode user list.
final allUsersForAdminProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(portfolioServiceProvider).fetchAllUsers();
});

// ── Admin apply-return notifier ──────────────────────────────────────────────

class ApplyReturnState {
  const ApplyReturnState({
    this.isProcessing = false,
    this.result,
    this.error,
  });
  final bool isProcessing;
  final Map<String, dynamic>? result;
  final String? error;
}

class ApplyReturnNotifier extends StateNotifier<ApplyReturnState> {
  ApplyReturnNotifier(this._ref) : super(const ApplyReturnState());

  final Ref _ref;

  PortfolioService get _service => _ref.read(portfolioServiceProvider);

  String get _adminUid =>
      _ref.read(firebaseAuthProvider).currentUser?.uid ?? "unknown_admin";

  /// Apply a single percentage to ALL portfolio holders.
  Future<Map<String, dynamic>> applyPercentageToAll(double pct) async {
    state = const ApplyReturnState(isProcessing: true);
    try {
      final result = await _service.applyPercentageToAll(
        returnPct: pct,
        adminUid: _adminUid,
      );
      state = ApplyReturnState(result: result);
      return result;
    } catch (e) {
      state = ApplyReturnState(error: e.toString());
      rethrow;
    }
  }

  /// Apply a manual profit amount to a single user.
  Future<double> applyManualToUser({
    required String uid,
    required double profitAmount,
  }) async {
    state = const ApplyReturnState(isProcessing: true);
    try {
      final profit = await _service.applyReturnToUser(
        uid: uid,
        returnPct: 0,
        adminUid: _adminUid,
        mode: "manual",
        manualProfitAmount: profitAmount,
      );
      state = ApplyReturnState(result: {"successCount": 1, "totalProfit": profit});
      return profit;
    } catch (e) {
      state = ApplyReturnState(error: e.toString());
      rethrow;
    }
  }

  void reset() => state = const ApplyReturnState();
}

final applyReturnProvider =
    StateNotifierProvider<ApplyReturnNotifier, ApplyReturnState>(
  (ref) => ApplyReturnNotifier(ref),
);

// ── Convenience: current user's portfolio ────────────────────────────────────

/// Shortcut provider — streams the signed-in user's own portfolio.
final myPortfolioProvider = StreamProvider<PortfolioModel?>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(null);
  return ref.read(portfolioServiceProvider).streamPortfolio(uid);
});

/// Shortcut provider — streams the signed-in user's own return history.
final myReturnHistoryProvider =
    StreamProvider<List<ReturnHistoryModel>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value([]);
  return ref.read(portfolioServiceProvider).streamReturnHistory(uid);
});
