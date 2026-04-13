import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../providers/auth_providers.dart";

final userNotificationsStreamProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>?>((ref) {
  return authBoundFirestoreStream<QuerySnapshot<Map<String, dynamic>>?>(
    ref,
    whenSignedOut: null,
    body: (user) => ref.read(firebaseFirestoreProvider)
        .collection("users")
        .doc(user.uid)
        .collection("notifications")
        .orderBy("createdAt", descending: true)
        .limit(100)
        .snapshots(),
  );
});

final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  return authBoundFirestoreStream<int>(
    ref,
    whenSignedOut: 0,
    body: (user) => ref
        .read(firebaseFirestoreProvider)
        .collection("users")
        .doc(user.uid)
        .collection("notifications")
        .where("read", isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length),
  );
});
