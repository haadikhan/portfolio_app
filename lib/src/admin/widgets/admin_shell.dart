import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../core/i18n/app_translations.dart";
import "../../core/widgets/app_bar_actions.dart";
import "../../features/notifications/providers/notification_providers.dart";
import "../providers/admin_providers.dart";

/// Ordered routes for [NavigationRail] and [Drawer] (must stay in sync).
const _kAdminShellRoutes = <String>[
  "/dashboard",
  "/kyc",
  "/deposits",
  "/withdrawals",
  "/investors",
  "/returns",
  "/upload-reports",
  "/notifications",
  "/broadcast",
];

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  void _go(BuildContext context, String route) {
    Navigator.of(context).maybePop();
    context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(adminRoleProvider);
    return roleAsync.when(
      data: (role) {
        if (role != "admin") {
          return Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      context.tr("admin_access_required"),
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr("admin_role_required"),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.go("/login"),
                      child: Text(context.tr("back_to_login")),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final loc = GoRouterState.of(context).matchedLocation;
        final scheme = Theme.of(context).colorScheme;

        return Scaffold(
          drawer: Drawer(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text(
                      "Wakalat Invest — Admin",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.dashboard_outlined),
                    title: Text(context.tr("overview")),
                    selected: loc.startsWith("/dashboard"),
                    onTap: () => _go(context, "/dashboard"),
                  ),
                  ListTile(
                    leading: const Icon(Icons.assignment_outlined),
                    title: Text(context.tr("kyc_queue")),
                    selected: loc.startsWith("/kyc"),
                    onTap: () => _go(context, "/kyc"),
                  ),
                  ListTile(
                    leading: const Icon(Icons.inbox_outlined),
                    title: Text(context.tr("deposits")),
                    selected: loc.startsWith("/deposits"),
                    onTap: () => _go(context, "/deposits"),
                  ),
                  ListTile(
                    leading: const Icon(Icons.outbox_outlined),
                    title: Text(context.tr("withdrawals")),
                    selected: loc.startsWith("/withdrawals"),
                    onTap: () => _go(context, "/withdrawals"),
                  ),
                  ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(context.tr("investors")),
                    selected: loc.startsWith("/investors"),
                    onTap: () => _go(context, "/investors"),
                  ),
                  ListTile(
                    leading: const Icon(Icons.trending_up_outlined),
                    title: Text(context.tr("returns")),
                    selected: loc.startsWith("/returns"),
                    onTap: () => _go(context, "/returns"),
                  ),
                  ListTile(
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(context.tr("admin_nav_upload_reports")),
                    selected: loc.startsWith("/upload-reports"),
                    onTap: () => _go(context, "/upload-reports"),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.inbox_outlined,
                      color: scheme.primary,
                    ),
                    title: Text(context.tr("notifications")),
                    subtitle: Text(context.tr("notifications_subtitle")),
                    selected: loc.startsWith("/notifications"),
                    onTap: () => _go(context, "/notifications"),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.campaign_outlined,
                      color: scheme.primary,
                    ),
                    title: Text(context.tr("broadcast_to_investors")),
                    selected: loc.startsWith("/broadcast"),
                    onTap: () => _go(context, "/broadcast"),
                  ),
                ],
              ),
            ),
          ),
          appBar: AppBar(
            title: const Text("Wakalat Invest — Admin"),
            // Bell first so it stays visible when the bar overflows on narrow widths.
            actions: [
              Consumer(
                builder: (context, ref, _) {
                  final unread = ref.watch(unreadNotificationCountProvider);
                  return unread.when(
                    data: (count) {
                      final btn = IconButton(
                        tooltip: context.tr("notifications"),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: Icon(
                          Icons.notifications_outlined,
                          size: 26,
                          color: scheme.primary,
                        ),
                        onPressed: () => context.go("/notifications"),
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
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: Icon(
                        Icons.notifications_outlined,
                        size: 26,
                        color: scheme.primary,
                      ),
                      onPressed: () => context.go("/notifications"),
                    ),
                    error: (_, __) => IconButton(
                      tooltip: context.tr("notifications"),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: Icon(
                        Icons.notifications_outlined,
                        size: 26,
                        color: scheme.primary,
                      ),
                      onPressed: () => context.go("/notifications"),
                    ),
                  );
                },
              ),
              const AppBarPreferenceActions(showNotificationAction: false),
              TextButton(
                onPressed: () async {
                  await ref
                      .read(adminAuthControllerProvider.notifier)
                      .signOut();
                  if (context.mounted) context.go("/login");
                },
                child: Text(context.tr("sign_out")),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final useRail = constraints.maxWidth >= 720;
              if (!useRail) {
                return child;
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NavigationRail(
                    selectedIndex: _indexFor(loc),
                    onDestinationSelected: (i) {
                      if (i >= 0 && i < _kAdminShellRoutes.length) {
                        context.go(_kAdminShellRoutes[i]);
                      }
                    },
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      NavigationRailDestination(
                        icon: const Icon(Icons.dashboard_outlined),
                        selectedIcon: const Icon(Icons.dashboard),
                        label: Text(context.tr("overview")),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.assignment_outlined),
                        selectedIcon: const Icon(Icons.assignment),
                        label: Text(context.tr("kyc_queue")),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.inbox_outlined),
                        selectedIcon: const Icon(Icons.inbox),
                        label: Text(context.tr("deposits")),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.outbox_outlined),
                        selectedIcon: const Icon(Icons.outbox),
                        label: Text(context.tr("withdrawals")),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.groups_outlined),
                        selectedIcon: const Icon(Icons.groups),
                        label: Text(context.tr("investors")),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.trending_up_outlined),
                        selectedIcon: const Icon(Icons.trending_up),
                        label: Text(context.tr("returns")),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        selectedIcon: const Icon(Icons.picture_as_pdf),
                        label: Text(context.tr("admin_nav_upload_reports")),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.inbox_outlined),
                        selectedIcon: const Icon(Icons.inbox),
                        label: Text(context.tr("notifications")),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.campaign_outlined),
                        selectedIcon: const Icon(Icons.campaign),
                        label: Text(context.tr("broadcast_to_investors")),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: child),
                ],
              );
            },
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text("Error: $e"))),
    );
  }

  int _indexFor(String loc) {
    if (loc.startsWith("/broadcast")) return 8;
    if (loc.startsWith("/notifications")) return 7;
    if (loc.startsWith("/upload-reports")) return 6;
    if (loc.startsWith("/investors")) return 4;
    if (loc.startsWith("/kyc")) return 1;
    if (loc.startsWith("/deposits")) return 2;
    if (loc.startsWith("/withdrawals")) return 3;
    if (loc.startsWith("/returns")) return 5;
    return 0;
  }
}
