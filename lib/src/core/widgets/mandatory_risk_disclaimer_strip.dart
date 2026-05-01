import "package:flutter/material.dart";

import "../i18n/app_translations.dart";

/// Trust-forward onboarding note (EN/Ur via [AppTranslations]).
///
/// Paragraph keys: [mandatory_disclaimer_p1] … [mandatory_disclaimer_p6].
class MandatoryRiskDisclaimerStrip extends StatelessWidget {
  const MandatoryRiskDisclaimerStrip({super.key});

  static const _paragraphKeys = <String>[
    "mandatory_disclaimer_p1",
    "mandatory_disclaimer_p2",
    "mandatory_disclaimer_p3",
    "mandatory_disclaimer_p4",
    "mandatory_disclaimer_p5",
    "mandatory_disclaimer_p6",
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final onSurface = scheme.onSurface;

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 22,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr("mandatory_disclaimer_subtitle_strip"),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                          height: 1.35,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < _paragraphKeys.length; i++) ...[
              Text(
                context.tr(_paragraphKeys[i]),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.55,
                      color: muted,
                    ),
              ),
              if (i < _paragraphKeys.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
