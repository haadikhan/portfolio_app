import "package:firebase_auth/firebase_auth.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../features/service_requests/models/change_request.dart";
import "../../providers/auth_providers.dart";
import "../services/admin_change_request_service.dart";

final adminChangeRequestServiceProvider = Provider<AdminChangeRequestService>(
  (ref) => AdminChangeRequestService(ref.watch(firebaseFirestoreProvider)),
);

/// Pending tickets across **all** investors (`collectionGroup("changeRequests")`).
final pendingChangeRequestsAdminProvider =
    StreamProvider<List<ChangeRequest>>((ref) {
  return ref
      .watch(adminChangeRequestServiceProvider)
      .watchPendingAcrossInvestors();
});

final adminAllChangeRequestsProvider = StreamProvider<List<ChangeRequest>>(
  (ref) {
    return ref.watch(adminChangeRequestServiceProvider).watchAllAcrossInvestors();
  },
);

final investorChangeRequestsProvider =
    StreamProvider.family<List<ChangeRequest>, String>((ref, uid) {
  return ref
      .watch(adminChangeRequestServiceProvider)
      .watchForInvestor(uid);
});

final adminChangeRequestActionProvider =
    AsyncNotifierProvider<AdminChangeRequestActionNotifier, void>(
      AdminChangeRequestActionNotifier.new,
    );

class AdminChangeRequestActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AdminChangeRequestService get _svc =>
      ref.read(adminChangeRequestServiceProvider);

  String get _adminUid =>
      FirebaseAuth.instance.currentUser?.uid ??
      (throw StateError("Admin not authenticated"));

  Future<void> approve(ChangeRequest r, {String? note}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _svc.approve(
        request: r,
        adminUid: _adminUid,
        note: note,
      );
      ref.invalidate(pendingChangeRequestsAdminProvider);
      ref.invalidate(adminAllChangeRequestsProvider);
      ref.invalidate(investorChangeRequestsProvider(r.uid));
    });
  }

  Future<void> reject(ChangeRequest r, {String? note}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _svc.reject(
        request: r,
        adminUid: _adminUid,
        note: note,
      );
      ref.invalidate(pendingChangeRequestsAdminProvider);
      ref.invalidate(adminAllChangeRequestsProvider);
      ref.invalidate(investorChangeRequestsProvider(r.uid));
    });
  }
}
