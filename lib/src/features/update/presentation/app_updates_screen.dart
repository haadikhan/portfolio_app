import "package:flutter/foundation.dart"
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../data/app_update_providers.dart";
import "update_action.dart";

class AppUpdatesScreen extends ConsumerWidget {
  const AppUpdatesScreen({super.key});

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(appReleaseStreamProvider);
    ref.invalidate(installedAppVersionProvider);
    await ref.read(installedAppVersionProvider.future);
    await ref.read(appReleaseStreamProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageGradient = isDark
        ? [scheme.surface, scheme.surfaceContainerLowest]
        : [AppColors.backgroundTop, AppColors.backgroundBottom];

    return AppScaffold(
      title: context.tr("app_updates_title"),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: pageGradient,
          ),
        ),
        child: _isAndroid
            ? _AndroidUpdatesBody(onRefresh: () => _onRefresh(ref))
            : _NonAndroidBody(),
      ),
    );
  }
}

class _NonAndroidBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        Icon(
          Icons.store_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          context.tr("app_updates_non_android"),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _AndroidUpdatesBody extends ConsumerWidget {
  const _AndroidUpdatesBody({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installedAsync = ref.watch(installedAppVersionProvider);
    final releaseAsync = ref.watch(appReleaseStreamProvider);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _InstalledVersionCard(installedAsync: installedAsync),
          const SizedBox(height: 16),
          releaseAsync.when(
            loading: () => _StatusCard(
              child: Row(
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr("app_updates_checking"),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            error: (_, __) => _StatusCard(
              child: Text(
                context.tr("app_updates_no_info"),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            data: (release) {
              if (release == null) {
                return _StatusCard(
                  child: Text(
                    context.tr("app_updates_no_info"),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }

              final installed = installedAsync.valueOrNull;
              final installedCode = installed?.$1 ?? 0;
              final installedName = installed?.$2 ?? "—";
              final isOutdated = installedCode < release.versionCode;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LatestVersionCard(release: release),
                  const SizedBox(height: 16),
                  if (isOutdated) ...[
                    _StatusChip(
                      label: context.tr("app_updates_available"),
                      background: AppColors.warning.withValues(alpha: 0.15),
                      foreground: AppColors.warning,
                      icon: Icons.system_update_alt_rounded,
                    ),
                    if (release.title.trim().isNotEmpty ||
                        release.message.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _ReleaseNotesCard(release: release),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () =>
                          openReleaseUpdate(context, ref, release),
                      icon: const Icon(Icons.download_rounded),
                      label: Text(context.tr("app_updates_update_now")),
                    ),
                  ] else ...[
                    _StatusChip(
                      label: context.tr("app_updates_up_to_date"),
                      background: AppColors.success.withValues(alpha: 0.12),
                      foreground: AppColors.success,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                    if (installedName.isNotEmpty &&
                        release.versionName.isNotEmpty &&
                        installedCode >= release.versionCode) ...[
                      const SizedBox(height: 12),
                      Text(
                        "${context.tr("app_updates_installed_version")}: "
                        "$installedName (${context.tr("app_updates_build")} "
                        "$installedCode)",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InstalledVersionCard extends StatelessWidget {
  const _InstalledVersionCard({required this.installedAsync});

  final AsyncValue<(int, String)> installedAsync;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      icon: Icons.phone_android_rounded,
      title: context.tr("app_updates_installed_version"),
      child: installedAsync.when(
        loading: () => const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (_, __) => Text(
          "—",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        data: (installed) {
          final (code, name) = installed;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isNotEmpty ? name : "—",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                "${context.tr("app_updates_build")} $code",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LatestVersionCard extends StatelessWidget {
  const _LatestVersionCard({required this.release});

  final AppReleaseInfo release;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      icon: Icons.new_releases_outlined,
      title: context.tr("app_updates_latest_version"),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            release.versionName.isNotEmpty ? release.versionName : "—",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (release.versionCode > 0) ...[
            const SizedBox(height: 4),
            Text(
              "${context.tr("app_updates_build")} ${release.versionCode}",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReleaseNotesCard extends StatelessWidget {
  const _ReleaseNotesCard({required this.release});

  final AppReleaseInfo release;

  @override
  Widget build(BuildContext context) {
    final title = release.title.trim();
    final message = release.message.trim();

    return _InfoCard(
      icon: Icons.article_outlined,
      title: context.tr("app_updates_release_notes"),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          if (title.isNotEmpty && message.isNotEmpty) const SizedBox(height: 8),
          if (message.isNotEmpty)
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
