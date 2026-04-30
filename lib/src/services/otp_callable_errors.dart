import "package:cloud_functions/cloud_functions.dart";
import "package:flutter/widgets.dart";

import "../core/i18n/app_translations.dart";

/// Maps [FirebaseFunctionsException.code] for phone-verify / trust-device callables.
String trFirebasePhoneCallableError(
  BuildContext context,
  FirebaseFunctionsException e,
) {
  switch (e.code) {
    case "failed-precondition":
      return context.tr("otp_callable_failed_precondition");
    case "permission-denied":
      return context.tr("otp_callable_permission_denied");
    case "invalid-argument":
      return context.tr("otp_callable_invalid_argument");
    default:
      return context.tr("otp_challenge_generic_error");
  }
}
