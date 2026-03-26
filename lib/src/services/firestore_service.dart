import "package:cloud_firestore/cloud_firestore.dart";

import "../models/app_user.dart";

class FirestoreService {
  FirestoreService(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection("users");

  Future<void> createUserProfile(AppUser user) async {
    try {
      await _users.doc(user.id).set(user.toMap(), SetOptions(merge: true));
    } catch (_) {
      throw Exception("Could not create user profile.");
    }
  }

  Future<AppUser?> fetchUser(String userId) async {
    try {
      final doc = await _users.doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromMap(doc.id, doc.data()!);
    } catch (_) {
      throw Exception("Failed to fetch user data.");
    }
  }

  Future<void> updateUserProfile({
    required String userId,
    required String name,
  }) async {
    try {
      await _users.doc(userId).update({"name": name.trim()});
    } catch (_) {
      throw Exception("Failed to update profile.");
    }
  }

  Stream<AppUser?> streamUser(String userId) {
    return _users.doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromMap(doc.id, doc.data()!);
    });
  }
}
