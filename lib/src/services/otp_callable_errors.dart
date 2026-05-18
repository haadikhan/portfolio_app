import "package:cloud_functions/cloud_functions.dart";
import "package:flutter/widgets.dart";

import "../core/i18n/app_translations.dart";

/// Maps [FirebaseFunctionsException] for phone-verify / change-phone callables.
String trFirebasePhoneCallableError(
  BuildContext context,
  FirebaseFunctionsException e,
) {
  final raw = e.message?.trim() ?? "";
  switch (raw) {
    case "MPIN_WRONG":
      return context.tr("mpin_wrong");
    case "MPIN_LOCKED":
      return context.tr("mpin_locked_short");
    case "MPIN_NOT_SET":
      return context.tr("mpin_required_for_phone_change");
    case "MPIN_INVALID_FORMAT":
      return context.tr("mpin_invalid_format");
    case "USE_CHANGE_PHONE_FLOW":
      return context.tr("otp_use_change_phone_flow");
    case "NO_VERIFIED_PHONE":
      return context.tr("otp_callable_failed_precondition");
  }

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
