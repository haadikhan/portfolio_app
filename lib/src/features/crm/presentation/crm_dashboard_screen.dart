import "package:flutter/material.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_scaffold.dart";

class CrmDashboardScreen extends StatelessWidget {
  const CrmDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: context.tr("crm_title"),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text(context.tr("crm_assigned")),
            subtitle: Text(context.tr("crm_assigned_sub")),
          ),
          ListTile(
            title: Text(context.tr("crm_followups")),
            subtitle: Text(context.tr("crm_followups_sub")),
          ),
          ListTile(
            title: Text(context.tr("crm_comm_logs")),
            subtitle: Text(context.tr("crm_comm_logs_sub")),
          ),
          ListTile(
            title: Text(context.tr("crm_notes")),
            subtitle: Text(context.tr("crm_notes_sub")),
          ),
        ],
      ),
    );
  }
}
