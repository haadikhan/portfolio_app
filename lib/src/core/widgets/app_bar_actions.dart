import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../i18n/app_translations.dart";
import "../i18n/language_provider.dart";
import "../theme/theme_provider.dart";

/// Compact theme and language controls for app bars (matches dashboard/profile prefs).
class AppBarPreferenceActions extends ConsumerWidget {
  const AppBarPreferenceActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider).valueOrNull ?? ThemeMode.light;
    final locale = ref.watch(languageProvider).valueOrNull ?? const Locale("en");
    final isDark = themeMode == ThemeMode.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: context.tr("dark_mode"),
          icon: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
          onPressed: () =>
              ref.read(themeProvider.notifier).toggleTheme(),
        ),
        IconButton(
          tooltip: context.tr("language"),
          icon: const Icon(Icons.language_rounded),
          onPressed: () {
            final next = locale.languageCode == "ur" ? "en" : "ur";
            ref.read(languageProvider.notifier).setLanguage(next);
          },
        ),
      ],
    );
  }
}
