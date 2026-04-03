import "dart:async";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_messaging/firebase_messaging.dart";

const int _kMaxFcmTokens = 5;

/// Persists the current device token on [users/{uid}.fcmTokens] (capped, de-duped).
Future<void> upsertFcmToken(String uid, String token) async {
  if (token.isEmpty) return;
  final ref = FirebaseFirestore.instance.collection("users").doc(uid);
  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(ref);
    final raw = snap.data()?["fcmTokens"];
    final list = raw is List
        ? raw.map((e) => e.toString()).where((t) => t.length > 20).toList()
        : <String>[];
    final next = [...list.where((t) => t != token), token];
    while (next.length > _kMaxFcmTokens) {
      next.removeAt(0);
    }
    tx.set(ref, {"fcmTokens": next}, SetOptions(merge: true));
  });
}

StreamSubscription<String>? _tokenRefreshSub;

/// Requests permission (iOS/web), writes token + subscribes to refresh (once per process).
Future<void> syncFcmTokenForUser(String uid) async {
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();
  final token = await messaging.getToken();
  if (token != null && token.isNotEmpty) {
    await upsertFcmToken(uid, token);
  }
  await _tokenRefreshSub?.cancel();
  _tokenRefreshSub = messaging.onTokenRefresh.listen((t) {
    upsertFcmToken(uid, t);
  });
}

Future<void> disposeFcmTokenListener() async {
  await _tokenRefreshSub?.cancel();
  _tokenRefreshSub = null;
}
