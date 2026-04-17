import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../features/notifications/providers/notification_providers.dart";
import "../../providers/auth_providers.dart";
import "../i18n/app_translations.dart";
import "../i18n/language_provider.dart";
import "../theme/app_colors.dart";
import "../theme/theme_provider.dart";
import "app_error_dialog.dart";

/// Notifications shortcut plus theme and language controls for app bars.
class AppBarPreferenceActions extends ConsumerWidget {
  const AppBarPreferenceActions({
    super.key,
    this.showNotificationAction = true,
    this.showLogoutAction = true,
  });

  /// When false, hides the investor notifications shortcut (e.g. admin-only screens).
  final bool showNotificationAction;

  /// When false, hides logout (e.g. admin app bar already has a dedicated sign-out control).
  final bool showLogoutAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider).valueOrNull ?? ThemeMode.light;
    final locale = ref.watch(languageProvider).valueOrNull ?? const Locale("en");
    final isDark = themeMode == ThemeMode.dark;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showNotificationAction) _notificationBell(context, ref, scheme),
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
        if (showLogoutAction)
          IconButton(
            tooltip: context.tr("drawer_logout"),
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            onPressed: () async {
              try {
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go("/login");
              } catch (e) {
                if (context.mounted) await showAppErrorDialog(context, e);
              }
            },
          ),
      ],
    );
  }

  Widget _notificationBell(
    BuildContext context,
    WidgetRef ref,
    ColorScheme scheme,
  ) {
    final async = ref.watch(unreadNotificationCountProvider);
    return async.when(
      data: (count) {
        final btn = IconButton(
          tooltip: context.tr("notifications"),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: Icon(
            Icons.notifications_outlined,
            size: 24,
            color: scheme.primary,
          ),
          onPressed: () => context.push("/notifications"),
        );
        if (count <= 0) return btn;
        return Badge(
          label: Text(count > 99 ? "99+" : "$count"),
          child: btn,
        );
      },
      loading: () => IconButton(
        tooltip: context.tr("notifications"),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(
          Icons.notifications_outlined,
          size: 24,
          color: scheme.primary,
        ),
        onPressed: () => context.push("/notifications"),
      ),
      error: (_, __) => IconButton(
        tooltip: context.tr("notifications"),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(
          Icons.notifications_outlined,
          size: 24,
          color: scheme.primary,
        ),
        onPressed: () => context.push("/notifications"),
      ),
    );
  }
}
