import "package:flutter/material.dart";

import "../../../core/i18n/app_translations.dart";
import "mpin_keypad.dart";

/// Modal MPIN entry. Pops the entered 4-digit string on completion or `null`
/// when the user cancels. Used by the withdrawal flow before posting the
/// callable. The dialog only collects the PIN — verification happens server
/// side, and any wrong/locked errors are surfaced by the caller.
class MpinPromptDialog extends StatefulWidget {
  const MpinPromptDialog({super.key, this.subtitleOverride});

  final String? subtitleOverride;

  @override
  State<MpinPromptDialog> createState() => _MpinPromptDialogState();
}

class _MpinPromptDialogState extends State<MpinPromptDialog> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr("mpin_prompt_title"),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              widget.subtitleOverride ?? context.tr("mpin_prompt_subtitle"),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            MpinKeypad(
              errorText: _error,
              onCompleted: (pin) {
                Navigator.of(context).pop(pin);
              },
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: Text(context.tr("cancel")),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
