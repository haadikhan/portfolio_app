import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../providers/auth_providers.dart";

final userNotificationsStreamProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return const Stream.empty();
  }
  return ref.read(firebaseFirestoreProvider)
      .collection("users")
      .doc(uid)
      .collection("notifications")
      .orderBy("createdAt", descending: true)
      .limit(100)
      .snapshots();
});

final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream.value(0);
  }
  return ref.read(firebaseFirestoreProvider)
      .collection("users")
      .doc(uid)
      .collection("notifications")
      .where("read", isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);
});
