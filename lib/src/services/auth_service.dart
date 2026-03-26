import "package:firebase_auth/firebase_auth.dart";

class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? getCurrentUser() => _auth.currentUser;

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
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
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
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
      default:
        return fallback?.trim().isNotEmpty == true
            ? fallback!
            : "Authentication failed. Please try again.";
    }
  }
}
