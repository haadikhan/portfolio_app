import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/widgets.dart";

import "../core/i18n/app_translations.dart";

/// Maps [FirebaseAuthException.code] from phone credential / link flows to a
/// safe, localized UI string.
String trFirebasePhoneOtpError(BuildContext context, FirebaseAuthException e) {
  switch (e.code) {
    case "invalid-verification-code":
      return context.tr("otp_challenge_invalid_code");
    case "session-expired":
      return context.tr("otp_challenge_expired");
    case "too-many-requests":
      return context.tr("otp_challenge_too_many_requests");
    default:
      return context.tr("otp_challenge_generic_error");
  }
}
