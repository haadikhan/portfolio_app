import "package:flutter_riverpod/flutter_riverpod.dart";

import "../features/mpin/data/mpin_service.dart";
import "../features/mpin/data/mpin_status.dart";
import "auth_providers.dart";

final mpinServiceProvider = Provider<MpinService>((_) => MpinService());

/// Live MPIN status for the signed-in user. Re-emits on any change to
/// `users/{uid}` so toggles and lockout updates appear instantly.
final mpinStatusStreamProvider = StreamProvider<MpinStatus>((ref) {
  return authBoundFirestoreStream<MpinStatus>(
    ref,
    whenSignedOut: MpinStatus.empty,
    body: (user) => ref
        .read(firebaseFirestoreProvider)
        .collection("users")
        .doc(user.uid)
        .snapshots()
        .map((s) => MpinStatus.fromUserDoc(s.exists ? s.data() : null)),
  );
});
