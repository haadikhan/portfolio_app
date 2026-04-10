import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/app_user.dart";
import "../models/user_kyc.dart";
import "../services/auth_service.dart";
import "../services/firestore_service.dart";

Future<void> _ensureProfileWithDiagnostics(
  FirestoreService firestore,
  User user,
) async {
  try {
    await firestore.ensureUserProfileFromAuthUser(user);
  } on FirebaseException catch (e) {
    final m = e.message?.trim();
    throw Exception(
      "Profile bootstrap failed. [${e.code}]${m != null && m.isNotEmpty ? " $m" : ""}",
    );
  }
}

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

/// Resolves after auth restores (e.g. app restart). Avoids reading `currentUser` too early.
final currentUserProvider = Provider<User?>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.maybeWhen(
    data: (u) => u,
    orElse: () => ref.read(firebaseAuthProvider).currentUser,
  );
});

/// Follows [authStateChanges] then the Firestore user doc so restarts still load profile + kycStatus.
final userProfileProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges().asyncExpand((user) {
    if (user == null) {
      return Stream<AppUser?>.value(null);
    }
    return Stream<void>.fromFuture(
      _ensureProfileWithDiagnostics(
        ref.read(firestoreServiceProvider),
        user,
      ),
    ).asyncExpand<AppUser?>((_) {
      return ref.read(firestoreServiceProvider).streamUser(user.uid);
    });
  });
});

final userKycProvider = StreamProvider<UserKycRecord?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges().asyncExpand((user) {
    if (user == null) return Stream<UserKycRecord?>.value(null);
    return ref.read(firestoreServiceProvider).streamUserKyc(user.uid);
  });
});

final consentAcceptedProvider = StreamProvider<bool>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges().asyncExpand((user) {
    if (user == null) return Stream<bool>.value(false);
    return ref.read(firestoreServiceProvider).streamConsentAccepted(user.uid);
  });
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
      final createdUser = credential.user;
      if (createdUser == null) {
        throw Exception("Unable to create account. Please try again.");
      }

      // Single writer path for profile bootstrap avoids create/update races.
      await _firestore.ensureUserProfileFromAuthUser(createdUser);

      // Keep user's chosen display name in Firestore profile.
      final trimmedName = name.trim();
      if (trimmedName.isNotEmpty) {
        await _firestore.updateUserProfile(userId: createdUser.uid, name: trimmedName);
      }
    });
  }

  Future<void> login({required String email, required String password}) async {
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

  Future<void> submitKyc({
    required String cnicNumber,
    required String phone,
    required String address,
    required String bankName,
    required String nomineeName,
    required String nomineeCnic,
    required String nomineeRelation,
    String? ibanOrAccountNumber,
    String? accountTitle,
    String? cnicFrontUrl,
    String? cnicBackUrl,
    String? selfieUrl,
    Map<String, dynamic>? paymentProof,
  }) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) throw Exception("No active user session.");
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _firestore.submitKyc(
        userId: currentUser.uid,
        cnicNumber: cnicNumber,
        phone: phone,
        address: address,
        bankName: bankName,
        nomineeName: nomineeName,
        nomineeCnic: nomineeCnic,
        nomineeRelation: nomineeRelation,
        ibanOrAccountNumber: ibanOrAccountNumber,
        accountTitle: accountTitle,
        cnicFrontUrl: cnicFrontUrl,
        cnicBackUrl: cnicBackUrl,
        selfieUrl: selfieUrl,
        paymentProof: paymentProof,
      );
    });
  }

  Future<void> acceptConsent() async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) throw Exception("No active user session.");
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _firestore.persistConsent(userId: currentUser.uid, accepted: true);
    });
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>(
      (ref) => AuthController(ref),
    );
