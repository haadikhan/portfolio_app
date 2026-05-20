import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

export "../models/change_request.dart" show ChangeRequest, hasPendingForType;

import "../../../providers/auth_providers.dart";
import "../models/change_request.dart";

final changeRequestsProvider =
    StreamProvider<List<ChangeRequest>>((Ref ref) {
  return authBoundFirestoreStream<List<ChangeRequest>>(
    ref,
    whenSignedOut: const [],
    body: (user) => ref
        .read(firebaseFirestoreProvider)
        .collection("users")
        .doc(user.uid)
        .collection("changeRequests")
        .orderBy("requestedAt", descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(ChangeRequest.fromDoc).toList(),
        ),
  );
});

/// Pending-only subset for badges / lock UX.
final pendingChangeRequestsProvider = Provider<List<ChangeRequest>>((Ref ref) {
  final async = ref.watch(changeRequestsProvider);
  return async.maybeWhen(
    data: (list) =>
        list.where((r) => r.isPending).toList(growable: false),
    orElse: () => const [],
  );
});

final submitChangeRequestProvider =
    AsyncNotifierProvider<SubmitChangeRequestNotifier, void>(
      SubmitChangeRequestNotifier.new,
    );

class SubmitChangeRequestNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  FirebaseFirestore get _db => ref.read(firebaseFirestoreProvider);

  String get _uid =>
      ref.read(currentUserProvider)?.uid ?? (throw Exception("Not signed in"));

  Future<void> submit({
    required String requestType,
    required Map<String, dynamic> requestedFields,
    required Map<String, dynamic> currentFields,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db
          .collection("users")
          .doc(_uid)
          .collection("changeRequests")
          .add(
            ChangeRequest.createNewDocPayload(
              requestType: requestType,
              requestedFields: requestedFields,
              currentFields: currentFields,
            ),
          );
      ref.invalidate(changeRequestsProvider);
    });
  }
}
