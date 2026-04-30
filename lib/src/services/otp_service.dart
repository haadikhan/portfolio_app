import "dart:async";

import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/foundation.dart";

/// Result types for [OtpService.sendCode].
sealed class OtpSendResult {
  const OtpSendResult();
}

/// SMS code was sent to the user's phone. Pass [verificationId] to
/// [OtpService.credentialFor] together with the user-entered code.
class OtpCodeSent extends OtpSendResult {
  const OtpCodeSent(this.verificationId, this.resendToken);
  final String verificationId;
  final int? resendToken;
}

/// Android-only fast path: Google Play Services auto-detected the SMS and
/// already produced a verified [PhoneAuthCredential]. The challenge screen
/// should hide the manual-entry UI and immediately link the credential.
class OtpAutoFilled extends OtpSendResult {
  const OtpAutoFilled(this.credential);
  final PhoneAuthCredential credential;
}

class OtpFailed extends OtpSendResult {
  const OtpFailed(this.code, this.message);
  final String code;
  final String message;

  /// True when the failure is an app-attestation / Play Integrity issue
  /// (package + SHA not registered in Firebase Console).
  bool get isAttestationError {
    final lc = "${code.toLowerCase()} ${message.toLowerCase()}";
    return lc.contains("app-not-authorized") ||
        lc.contains("app_not_authorized") ||
        lc.contains("play_integrity") ||
        lc.contains("play integrity") ||
        lc.contains("invalid app info") ||
        lc.contains("invalid-app-credential") ||
        lc.contains("missing-app-credential") ||
        lc.contains("quota-exceeded");
  }
}

/// Wraps Firebase Phone Auth for the new-device OTP flow.
///
/// The phone credential is linked only long enough for server-side callers
/// (Cloud Functions reading `providerId == phone`) to observe it; callers use
/// [withTransientPhoneLink] so unlink runs after async work completes.
class OtpService {
  OtpService(this._auth);

  final FirebaseAuth _auth;

  Future<OtpSendResult> sendCode({
    required String phoneE164,
    Duration timeout = const Duration(seconds: 60),
    int? resendToken,
  }) {
    if (kDebugMode) {
      // Mask all but first 3 + last 2 digits for logs.
      final masked = phoneE164.length > 5
          ? "${phoneE164.substring(0, 3)}••••${phoneE164.substring(phoneE164.length - 2)}"
          : phoneE164;
      debugPrint("[OTP] sendCode → $masked (timeout=${timeout.inSeconds}s)");
    }

    final completer = Completer<OtpSendResult>();
    _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      timeout: timeout,
      forceResendingToken: resendToken,
      verificationCompleted: (PhoneAuthCredential credential) {
        if (kDebugMode) debugPrint("[OTP] verificationCompleted (auto-fill)");
        if (!completer.isCompleted) {
          completer.complete(OtpAutoFilled(credential));
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (kDebugMode) {
          debugPrint(
            "[OTP] verificationFailed code=${e.code} message=${e.message}",
          );
        }
        if (!completer.isCompleted) {
          completer.complete(OtpFailed(e.code, e.message ?? "Could not send OTP."));
        }
      },
      codeSent: (String verificationId, int? token) {
        if (kDebugMode) debugPrint("[OTP] codeSent verificationId=$verificationId");
        if (!completer.isCompleted) {
          completer.complete(OtpCodeSent(verificationId, token));
        }
      },
      codeAutoRetrievalTimeout: (String _) {
        // Manual-entry path. The codeSent callback already completed the
        // future, so nothing to do here.
      },
    );
    return completer.future;
  }

  PhoneAuthCredential credentialFor({
    required String verificationId,
    required String smsCode,
  }) {
    return PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
  }

  /// Links [credential], runs [whilePhoneLinked], then **always** tries to
  /// unlink the phone provider so the primary sign-in stays email/password.
  ///
  /// Cloud Functions use Admin Auth to read the linked phone; they must run
  /// inside [whilePhoneLinked] before unlink executes in `finally`.
  Future<T> withTransientPhoneLink<T>(
    PhoneAuthCredential credential,
    Future<T> Function() whilePhoneLinked,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: "no-current-user",
        message: "No signed-in user to link OTP credential to.",
      );
    }

    try {
      try {
        await user.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == "provider-already-linked" ||
            e.code == "credential-already-in-use") {
          // Already linked from an incomplete earlier attempt — still run server
          // work so Admin Auth can observe provider phone before unlink runs.
          if (kDebugMode) {
            debugPrint(
              "[OTP] withTransientPhoneLink: skip link (${e.code}), running work anyway",
            );
          }
        } else {
          rethrow;
        }
      }
      return await whilePhoneLinked();
    } finally {
      try {
        await _auth.currentUser?.unlink(PhoneAuthProvider.PROVIDER_ID);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint(
            "[OTP] unlink after transient link failed (non-fatal): $e\n$st",
          );
        }
      }
    }
  }
}
