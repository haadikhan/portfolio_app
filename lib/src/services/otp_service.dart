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
/// We deliberately do NOT keep the user signed in as the phone provider;
/// instead, after a successful credential the caller [linkAndUnlink]s it
/// against the existing email/password user purely to prove the OTP, then
/// the backend cleans up the link. This keeps the user's primary
/// authentication method (email + password) unchanged.
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

  /// Links the phone credential to the currently signed-in user, then
  /// immediately unlinks it. The transient link is the cryptographic proof
  /// that the user owns the phone for this session; the unlink keeps the
  /// account on a single primary provider (email + password).
  ///
  /// Returns the verified phone number reported by Firebase, or null if the
  /// link succeeded but the SDK didn't report a phone (very rare).
  Future<String?> linkAndUnlink(PhoneAuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: "no-current-user",
        message: "No signed-in user to link OTP credential to.",
      );
    }
    try {
      final result = await user.linkWithCredential(credential);
      final phone = result.user?.phoneNumber ?? user.phoneNumber;
      try {
        await user.unlink(PhoneAuthProvider.PROVIDER_ID);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint("[OTP] unlink after link failed (non-fatal): $e\n$st");
        }
      }
      return phone;
    } on FirebaseAuthException catch (e) {
      if (e.code == "provider-already-linked" ||
          e.code == "credential-already-in-use") {
        // Same user already has this phone linked from a previous attempt
        // that didn't get cleaned up. Treat as success and unlink to clean.
        try {
          await user.unlink(PhoneAuthProvider.PROVIDER_ID);
        } catch (_) {}
        return user.phoneNumber;
      }
      rethrow;
    }
  }
}
