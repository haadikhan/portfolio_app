import "package:flutter/material.dart";

import "../i18n/app_translations.dart";

/// Verbatim mandatory risk lines (section 12.1) — EN/Ur via [AppTranslations].
class MandatoryRiskDisclaimerStrip extends StatelessWidget {
  const MandatoryRiskDisclaimerStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;

    return Card(
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.gavel_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.tr("mandatory_disclaimer_heading"),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Line(text: context.tr("mandatory_disclaimer_line_1"), muted: muted),
            const SizedBox(height: 10),
            _Line(text: context.tr("mandatory_disclaimer_line_2"), muted: muted),
            const SizedBox(height: 10),
            _Line(text: context.tr("mandatory_disclaimer_line_3"), muted: muted),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.text, required this.muted});

  final String text;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final lead = _leadSentence(text);
    final rest = _rest(text);
    return Text.rich(
      TextSpan(
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          height: 1.4,
          color: muted,
        ),
        children: [
          TextSpan(
            text: rest.isEmpty ? lead : "$lead ",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: onSurface,
            ),
          ),
          if (rest.isNotEmpty) TextSpan(text: rest),
        ],
      ),
    );
  }

  /// First sentence shown bold (up to first Latin or Arabic full stop).
  static String _leadSentence(String s) {
    final i = _firstSentenceEnd(s);
    if (i < 0) return s;
    return s.substring(0, i + 1).trim();
  }

  static String _rest(String s) {
    final i = _firstSentenceEnd(s);
    if (i < 0 || i + 1 >= s.length) return "";
    return s.substring(i + 1).trim();
  }

  static int _firstSentenceEnd(String s) {
    const arabicStop = "\u06D4";
    final dot = s.indexOf(".");
    final ar = s.indexOf(arabicStop);
    if (dot < 0) return ar;
    if (ar < 0) return dot;
    return dot < ar ? dot : ar;
  }
}
