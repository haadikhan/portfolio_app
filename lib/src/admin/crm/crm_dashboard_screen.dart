import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../core/i18n/app_translations.dart";
import "../../providers/auth_providers.dart";
import "../providers/admin_providers.dart";
import "crm_providers.dart";

/// CRM home: pending follow-up count and quick link to assigned investors.
class CrmDashboardScreen extends ConsumerWidget {
  const CrmDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider)?.uid;
    final role = ref.watch(adminRoleProvider).valueOrNull ?? "";
    final isAdmin = role.toLowerCase() == "admin";

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr("crm_dashboard_title"),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          if (!isAdmin && uid != null) ...[
            ref.watch(crmPendingFollowupsCountProvider(uid)).when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => Text(context.tr("error_prefix")),
                  data: (n) => Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.event_available_outlined),
                      title: Text(context.tr("crm_pending_followups")),
                      trailing: Text(
                        "$n",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            onPressed: () => context.go("/crm/investors"),
            icon: const Icon(Icons.groups_outlined),
            label: Text(context.tr("crm_nav_investors")),
          ),
        ],
      ),
    );
  }
}
