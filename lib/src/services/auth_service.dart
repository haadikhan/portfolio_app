import "package:firebase_auth/firebase_auth.dart";
import "package:cloud_functions/cloud_functions.dart";

class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: "us-central1");

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? getCurrentUser() => _auth.currentUser;

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.getIdToken(true);
      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_messageForCode(e.code, fallback: e.message));
    } catch (_) {
      throw Exception("Unable to sign up right now. Please try again.");
    }
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final trimmed = email.trim();
    try {
      // Never call fetchSignInMethodsForEmail before sign-in: with Firebase email
      // enumeration protection it often returns [] for real users, which made us show
      // "no account" before wrong-password / invalid-credential could run.
      final credential = await _auth.signInWithEmailAndPassword(
        email: trimmed,
        password: password,
      );
      await credential.user?.getIdToken(true);
      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_messageForCode(e.code, fallback: e.message));
    } catch (_) {
      throw Exception("Unable to login right now. Please try again.");
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (_) {
      throw Exception("Could not logout. Please try again.");
    }
  }

  Future<void> sendInvestorLoginAlert() async {
    try {
      await _functions.httpsCallable("sendInvestorLoginAlert").call();
    } on FirebaseFunctionsException catch (_) {
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  /// Sends Firebase's password-reset email (email/password accounts only).
  /// Completes without error for [user-not-found] to avoid email enumeration.
  Future<void> sendPasswordResetEmail({required String email}) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw Exception(_messageForCode("invalid-email"));
    }
    try {
      await _auth.sendPasswordResetEmail(email: trimmed);
    } on FirebaseAuthException catch (e) {
      if (e.code == "user-not-found") {
        return;
      }
      throw Exception(_messageForCode(e.code, fallback: e.message));
    } catch (_) {
      throw Exception("Unable to send reset email. Please try again.");
    }
  }

  /// Re-authenticates with the current email/password, then updates the password.
  /// Call only for users with the email/password provider linked.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email?.trim();
    if (user == null || email == null || email.isEmpty) {
      throw Exception("No signed-in account or email is missing.");
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw Exception(_messageForCode(e.code, fallback: e.message));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception("Could not update password. Please try again.");
    }
  }

  String _messageForCode(String code, {String? fallback}) {
    switch (code) {
      case "email-already-in-use":
        return "This email is already registered.";
      case "invalid-email":
        return "Please enter a valid email address.";
      case "weak-password":
        return "Password is too weak. Use at least 6 characters.";
      case "user-not-found":
        return "No account found with this email.";
      case "wrong-password":
      case "invalid-credential":
        return "Invalid email or password.";
      case "too-many-requests":
        return "Too many attempts. Please try again later.";
      case "operation-not-allowed":
        return "Email/password sign-in is disabled in Firebase. Enable it from Authentication > Sign-in method.";
      case "network-request-failed":
        return "Network error. Please check your internet connection.";
      case "app-not-authorized":
        return "This app is not authorized for this Firebase project. Re-run FlutterFire configuration.";
      case "internal-error":
        return "Firebase internal error. Please try again in a moment.";
      case "requires-recent-login":
        return "For security, sign out and sign in again, then change your password.";
      case "credential-mismatch":
      case "invalid-verification-code":
      case "invalid-verification-id":
        return "Current password is incorrect.";
      default:
        return fallback?.trim().isNotEmpty == true
            ? fallback!
            : "Authentication failed. Please try again.";
    }
  }
}
