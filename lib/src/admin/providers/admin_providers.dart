import "package:firebase_auth/firebase_auth.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../providers/auth_providers.dart";
import "../models/admin_investor_models.dart";
import "../models/kyc_admin_models.dart";
import "../services/admin_investor_service.dart";
import "../services/admin_kyc_service.dart";
import "../services/admin_stats_service.dart";

final adminKycServiceProvider = Provider<AdminKycService>(
  (ref) => AdminKycService(ref.read(firebaseFirestoreProvider)),
);

final adminStatsServiceProvider = Provider<AdminStatsService>(
  (ref) => AdminStatsService(ref.read(firebaseFirestoreProvider)),
);

final adminInvestorServiceProvider = Provider<AdminInvestorService>(
  (ref) => AdminInvestorService(ref.read(firebaseFirestoreProvider)),
);

/// `users/{uid}.role` — `admin`, `investor`, `team`, etc.
final adminRoleProvider = StreamProvider<String?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges().asyncExpand((user) {
    if (user == null) {
      return Stream<String?>.value(null);
    }
    return Stream<void>.fromFuture(user.getIdToken(true)).asyncExpand((_) {
      return ref
          .read(firebaseFirestoreProvider)
          .collection("users")
          .doc(user.uid)
          .snapshots()
          .map((d) => (d.data()?["role"] as String? ?? "").toLowerCase());
    });
  });
});

final pendingKycQueueProvider = StreamProvider<List<KycAdminDocument>>((ref) {
  return ref.watch(adminKycServiceProvider).watchPendingKycQueue();
});

final kycDetailProvider =
    FutureProvider.family<KycAdminDocument?, String>((ref, userId) {
  return ref.read(adminKycServiceProvider).fetchKycDetail(userId);
});

final investorSearchQueryProvider = StateProvider<String>((ref) => "");

final allInvestorsProvider = FutureProvider<List<AdminInvestorSummary>>((ref) {
  return ref.read(adminInvestorServiceProvider).fetchInvestors();
});

final filteredInvestorsProvider = Provider<AsyncValue<List<AdminInvestorSummary>>>(
  (ref) {
    final investorsAsync = ref.watch(allInvestorsProvider);
    final query = ref.watch(investorSearchQueryProvider).trim().toLowerCase();
    return investorsAsync.whenData((investors) {
      if (query.isEmpty) return investors;
      return investors.where((u) {
        return u.name.toLowerCase().contains(query) ||
            u.email.toLowerCase().contains(query) ||
            u.phone.toLowerCase().contains(query);
      }).toList();
    });
  },
);

final investorDetailProvider =
    FutureProvider.family<AdminInvestorDetail?, String>((ref, userId) {
  return ref.read(adminInvestorServiceProvider).fetchInvestorDetail(userId);
});

class AdminAuthController extends StateNotifier<AsyncValue<void>> {
  AdminAuthController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  FirebaseAuth get _auth => _ref.read(firebaseAuthProvider);

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.getIdToken(true);
      final uid = cred.user?.uid;
      if (uid == null) throw Exception("Sign-in failed.");
      final doc = await _ref.read(firebaseFirestoreProvider).collection("users").doc(uid).get();
      final role = (doc.data()?["role"] as String? ?? "").toLowerCase();
      if (role != "admin" && role != "crm") {
        await _auth.signOut();
        throw Exception(
          "Access denied. This panel is for administrators and CRM staff only.",
        );
      }
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _auth.signOut();
    });
  }
}

final adminAuthControllerProvider =
    StateNotifierProvider<AdminAuthController, AsyncValue<void>>(
  AdminAuthController.new,
);
