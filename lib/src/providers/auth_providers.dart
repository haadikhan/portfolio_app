import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/app_user.dart";
import "../services/auth_service.dart";
import "../services/firestore_service.dart";

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (_) => FirebaseAuth.instance,
);

final firebaseFirestoreProvider = Provider<FirebaseFirestore>(
  (_) => FirebaseFirestore.instance,
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.read(firebaseAuthProvider)),
);

final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(ref.read(firebaseFirestoreProvider)),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.read(authServiceProvider).authStateChanges(),
);

final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).currentUser,
);

final userProfileProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).streamUser(user.uid);
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  AuthService get _auth => _ref.read(authServiceProvider);
  FirestoreService get _firestore => _ref.read(firestoreServiceProvider);

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final credential = await _auth.signUp(email: email, password: password);
      final uid = credential.user?.uid;
      if (uid == null) {
        throw Exception("Unable to create account. Please try again.");
      }
      final user = AppUser(
        id: uid,
        email: email.trim(),
        name: name.trim(),
        createdAt: DateTime.now(),
      );
      await _firestore.createUserProfile(user);
    });
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _auth.login(email: email, password: password);
    });
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _auth.logout();
    });
  }

  Future<void> updateProfileName(String name) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) throw Exception("No active user session.");
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _firestore.updateUserProfile(userId: currentUser.uid, name: name);
    });
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>(
  (ref) => AuthController(ref),
);
