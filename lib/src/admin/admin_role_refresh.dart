import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/foundation.dart";

/// Keeps [role] in sync with [FirebaseAuth] + Firestore `users/{uid}.role`
/// so [GoRouter.redirect] can read it synchronously after the first load.
final class AdminRoleRefresh extends ChangeNotifier {
  AdminRoleRefresh() {
    _syncUser(FirebaseAuth.instance.currentUser);
    FirebaseAuth.instance.authStateChanges().listen(_syncUser);
  }

  String? _role;
  bool _ready = false;

  String? get role => _role;

  /// False while fetching role for the signed-in user.
  bool get ready => _ready;

  void _syncUser(User? user) {
    if (user == null) {
      _role = null;
      _ready = true;
      notifyListeners();
      return;
    }
    _ready = false;
    notifyListeners();
    FirebaseFirestore.instance.collection("users").doc(user.uid).get().then(
      (doc) {
        _role = (doc.data()?["role"] as String? ?? "").toLowerCase();
        _ready = true;
        notifyListeners();
      },
      onError: (_) {
        _role = null;
        _ready = true;
        notifyListeners();
      },
    );
  }
}

/// Singleton for [GoRouter.refreshListenable].
final adminRoleRefresh = AdminRoleRefresh();
