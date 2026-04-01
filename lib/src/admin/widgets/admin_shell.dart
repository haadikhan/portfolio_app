import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../core/i18n/app_translations.dart";
import "../../core/widgets/app_bar_actions.dart";
import "../providers/admin_providers.dart";

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

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
        return Scaffold(
          appBar: AppBar(
            title: const Text("Wakalat Invest — Admin"),
            actions: [
              TextButton(
                onPressed: () async {
                  await ref
                      .read(adminAuthControllerProvider.notifier)
                      .signOut();
                  if (context.mounted) context.go("/login");
                },
                child: Text(context.tr("sign_out")),
              ),
              const AppBarPreferenceActions(),
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NavigationRail(
                selectedIndex: _indexFor(loc),
                onDestinationSelected: (i) {
                  switch (i) {
                    case 0:
                      context.go("/dashboard");
                    case 1:
                      context.go("/kyc");
                    case 2:
                      context.go("/deposits");
                    case 3:
                      context.go("/withdrawals");
                    case 4:
                      context.go("/investors");
                    case 5:
                      context.go("/returns");
                  }
                },
                labelType: NavigationRailLabelType.all,
                destinations: [
                  NavigationRailDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: Text(context.tr("overview")),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.assignment_outlined),
                    selectedIcon: Icon(Icons.assignment),
                    label: Text(context.tr("kyc_queue")),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.inbox_outlined),
                    selectedIcon: Icon(Icons.inbox),
                    label: Text(context.tr("deposits")),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.outbox_outlined),
                    selectedIcon: Icon(Icons.outbox),
                    label: Text(context.tr("withdrawals")),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.groups_outlined),
                    selectedIcon: Icon(Icons.groups),
                    label: Text(context.tr("investors")),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.trending_up_outlined),
                    selectedIcon: Icon(Icons.trending_up),
                    label: Text(context.tr("returns")),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: child),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text("Error: $e")),
      ),
    );
  }

  int _indexFor(String loc) {
    if (loc.startsWith("/investors")) return 4;
    if (loc.startsWith("/kyc")) return 1;
    if (loc.startsWith("/deposits")) return 2;
    if (loc.startsWith("/withdrawals")) return 3;
    if (loc.startsWith("/returns")) return 5;
    return 0;
  }
}
