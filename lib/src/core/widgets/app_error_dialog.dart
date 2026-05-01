import "package:flutter/material.dart";

import "../firebase/app_check_auth_errors.dart";
import "../i18n/app_translations.dart";

/// User-facing text for auth/async failures (matches [LoginScreen] / SnackBar behavior).
String formatAppErrorMessage(BuildContext context, Object error) {
  final s = error.toString();
  final body = s.startsWith("Exception: ")
      ? s.substring("Exception: ".length)
      : s;
  if (looksLikeFirebaseAuthAppCheckInvalid(
        code: "",
        messageOrFallback: body,
      )) {
    return firebaseAuthAppCheckBlockedUserMessage();
  }
  return body;
}

/// Non-blocking error alert (e.g. after [AsyncValue] failure or thrown [Exception]).
Future<void> showAppErrorDialog(BuildContext context, Object error) {
  return showAppErrorMessageDialog(
    context,
    formatAppErrorMessage(context, error),
  );
}

/// Pre-formatted message (e.g. deposit/withdraw friendly strings).
Future<void> showAppErrorMessageDialog(
  BuildContext context,
  String message,
) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.tr("error_alert_title")),
      content: SingleChildScrollView(
        child: Text(
          message,
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(context.tr("dialog_ok")),
        ),
      ],
    ),
  );
}
