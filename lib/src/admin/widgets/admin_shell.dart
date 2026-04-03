import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../core/i18n/app_translations.dart";
import "../../core/widgets/app_bar_actions.dart";
import "../../features/notifications/providers/notification_providers.dart";
import "../providers/admin_providers.dart";

/// Ordered routes for [NavigationRail] / [Drawer] — admin (full) layout.
const _kAdminShellRoutes = <String>[
  "/dashboard",
  "/kyc",
  "/deposits",
  "/withdrawals",
  "/investors",
  "/crm",
  "/crm/investors",
  "/crm/team",
  "/returns",
  "/upload-reports",
  "/notifications",
  "/broadcast",
];

/// CRM-only staff: CRM area + notifications.
const _kCrmShellRoutes = <String>[
  "/crm",
  "/crm/investors",
  "/notifications",
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
      data: (roleRaw) {
        final role = (roleRaw ?? "").toLowerCase();
        final isAdmin = role == "admin";
        final isCrm = role == "crm";
        final staff = isAdmin || isCrm;

        if (!staff) {
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
                      context.tr("staff_access_required"),
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr("staff_role_required"),
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
        final barTitle = isCrm
            ? context.tr("crm_app_bar_staff")
            : "Wakalat Invest — Admin";

        return Scaffold(
          drawer: Drawer(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text(
                      barTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const Divider(height: 1),
                  if (isCrm) ...[
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: const Icon(Icons.hub_outlined),
                      title: Text(context.tr("crm_nav_dashboard")),
                      selected: loc == "/crm",
                      onTap: () => _go(context, "/crm"),
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: const Icon(Icons.groups_outlined),
                      title: Text(context.tr("crm_nav_investors")),
                      selected: loc.startsWith("/crm/investors"),
                      onTap: () => _go(context, "/crm/investors"),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: Icon(
                        Icons.inbox_outlined,
                        color: scheme.primary,
                      ),
                      title: Text(context.tr("notifications")),
                      subtitle: Text(context.tr("notifications_subtitle")),
                      selected: loc.startsWith("/notifications"),
                      onTap: () => _go(context, "/notifications"),
                    ),
                  ] else ...[
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: const Icon(Icons.dashboard_outlined),
                      title: Text(context.tr("overview")),
                      selected: loc.startsWith("/dashboard"),
                      onTap: () => _go(context, "/dashboard"),
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: const Icon(Icons.assignment_outlined),
                      title: Text(context.tr("kyc_queue")),
                      selected: loc.startsWith("/kyc"),
                      onTap: () => _go(context, "/kyc"),
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: const Icon(Icons.inbox_outlined),
                      title: Text(context.tr("deposits")),
                      selected: loc.startsWith("/deposits"),
                      onTap: () => _go(context, "/deposits"),
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: const Icon(Icons.outbox_outlined),
                      title: Text(context.tr("withdrawals")),
                      selected: loc.startsWith("/withdrawals"),
                      onTap: () => _go(context, "/withdrawals"),
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: const Icon(Icons.groups_outlined),
                      title: Text(context.tr("investors")),
                      selected: loc.startsWith("/investors") &&
                          !loc.startsWith("/crm"),
                      onTap: () => _go(context, "/investors"),
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: const Icon(Icons.hub_outlined),
                      title: Text(context.tr("crm_nav_dashboard")),
                      selected: loc == "/crm",
                      onTap: () => _go(context, "/crm"),
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: const Icon(Icons.contact_mail_outlined),
                      title: Text(context.tr("crm_nav_investors")),
                      selected: loc.startsWith("/crm/investors"),
                      onTap: () => _go(context, "/crm/investors"),
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: const Icon(Icons.manage_accounts_outlined),
                      title: Text(context.tr("crm_nav_team")),
                      selected: loc.startsWith("/crm/team"),
                      onTap: () => _go(context, "/crm/team"),
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: const Icon(Icons.trending_up_outlined),
                      title: Text(context.tr("returns")),
                      selected: loc.startsWith("/returns"),
                      onTap: () => _go(context, "/returns"),
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: const Icon(Icons.picture_as_pdf_outlined),
                      title: Text(context.tr("admin_nav_upload_reports")),
                      selected: loc.startsWith("/upload-reports"),
                      onTap: () => _go(context, "/upload-reports"),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      isThreeLine: false,
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
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: Icon(
                        Icons.campaign_outlined,
                        color: scheme.primary,
                      ),
                      title: Text(context.tr("broadcast_to_investors")),
                      selected: loc.startsWith("/broadcast"),
                      onTap: () => _go(context, "/broadcast"),
                    ),
                  ],
                ],
              ),
            ),
          ),
          appBar: AppBar(
            title: Text(barTitle),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 212,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        navigationRailTheme: NavigationRailThemeData(
                          backgroundColor: scheme.surface,
                          minExtendedWidth: 200,
                          selectedIconTheme: IconThemeData(
                            color: scheme.primary,
                            size: 22,
                          ),
                          unselectedIconTheme: IconThemeData(
                            color: scheme.onSurfaceVariant,
                            size: 22,
                          ),
                          selectedLabelTextStyle: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                          unselectedLabelTextStyle: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                        ),
                      ),
                      child: isCrm
                          ? _CrmNavigationRail(loc: loc)
                          : _AdminNavigationRail(loc: loc),
                    ),
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
}

class _CrmNavigationRail extends StatelessWidget {
  const _CrmNavigationRail({required this.loc});

  final String loc;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      extended: true,
      minExtendedWidth: 200,
      selectedIndex: _indexForCrm(loc),
      onDestinationSelected: (i) {
        if (i >= 0 && i < _kCrmShellRoutes.length) {
          context.go(_kCrmShellRoutes[i]);
        }
      },
      labelType: NavigationRailLabelType.none,
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.hub_outlined),
          selectedIcon: const Icon(Icons.hub),
          label: Text(context.tr("crm_nav_dashboard")),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.groups_outlined),
          selectedIcon: const Icon(Icons.groups),
          label: Text(context.tr("crm_nav_investors")),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.inbox_outlined),
          selectedIcon: const Icon(Icons.inbox),
          label: Text(context.tr("notifications")),
        ),
      ],
    );
  }
}

class _AdminNavigationRail extends StatelessWidget {
  const _AdminNavigationRail({required this.loc});

  final String loc;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      extended: true,
      minExtendedWidth: 200,
      selectedIndex: _indexForAdmin(loc),
      onDestinationSelected: (i) {
        if (i >= 0 && i < _kAdminShellRoutes.length) {
          context.go(_kAdminShellRoutes[i]);
        }
      },
      labelType: NavigationRailLabelType.none,
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
          icon: const Icon(Icons.hub_outlined),
          selectedIcon: const Icon(Icons.hub),
          label: Text(context.tr("crm_nav_dashboard")),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.contact_mail_outlined),
          selectedIcon: const Icon(Icons.contact_mail),
          label: Text(context.tr("crm_nav_investors")),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.manage_accounts_outlined),
          selectedIcon: const Icon(Icons.manage_accounts),
          label: Text(context.tr("crm_nav_team")),
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
    );
  }
}

int _indexForCrm(String loc) {
  if (loc.startsWith("/notifications")) return 2;
  if (loc.startsWith("/crm/investors")) return 1;
  if (loc.startsWith("/crm")) return 0;
  return 0;
}

int _indexForAdmin(String loc) {
  if (loc.startsWith("/broadcast")) return 11;
  if (loc.startsWith("/notifications")) return 10;
  if (loc.startsWith("/upload-reports")) return 9;
  if (loc.startsWith("/returns")) return 8;
  if (loc.startsWith("/crm/team")) return 7;
  if (loc.startsWith("/crm/investors")) return 6;
  if (loc.startsWith("/crm")) return 5;
  if (loc.startsWith("/investors")) return 4;
  if (loc.startsWith("/withdrawals")) return 3;
  if (loc.startsWith("/deposits")) return 2;
  if (loc.startsWith("/kyc")) return 1;
  return 0;
}
