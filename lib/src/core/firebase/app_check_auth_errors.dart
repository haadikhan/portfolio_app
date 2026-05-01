import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Auth error when App Check enforcement rejects the client's token (web/mobile).
///
/// [FirebaseAuthException.code] may be this value on some clients; on others the detail
/// appears only in [FirebaseAuthException.message] (especially Flutter web).
const String kFirebaseAuthAppCheckTokenInvalidCode =
    'firebase-app-check-token-is-invalid';

bool isFirebaseAuthAppCheckTokenInvalidCode(String code) {
  final c = code.trim().toLowerCase();
  return c == kFirebaseAuthAppCheckTokenInvalidCode ||
      c.contains('app-check-token-is-invalid');
}

/// True when [FirebaseAuthException] corresponds to App Check rejection (covers web quirks).
bool isFirebaseAuthAppCheckFailure(FirebaseAuthException e) {
  if (isFirebaseAuthAppCheckTokenInvalidCode(e.code)) return true;
  final msg = (e.message ?? '').toLowerCase();
  return msg.contains('firebase-app-check-token-is-invalid') ||
      msg.contains('app-check-token-is-invalid');
}

/// Detect App Check rejection from [.code] and/or a separate message/fallback string.
bool looksLikeFirebaseAuthAppCheckInvalid({
  required String code,
  String? messageOrFallback,
}) {
  if (isFirebaseAuthAppCheckTokenInvalidCode(code)) return true;
  final m = (messageOrFallback ?? '').toLowerCase();
  return m.contains('firebase-app-check-token-is-invalid') ||
      m.contains('app-check-token-is-invalid');
}

/// Short, actionable copy for dialogs (no Firebase jargon).
String firebaseAuthAppCheckBlockedUserMessage() {
  return 'Sign-in blocked by security verification on this browser. '
      'In Firebase Console → App Check → Manage debug tokens, add the debug token '
      'printed in your browser console (when no reCAPTCHA site key is set), or '
      'build with a registered reCAPTCHA site key — see docs/firebase_integration_setup.md.';
}
