import "package:flutter/material.dart";

import "../../../core/widgets/app_scaffold.dart";

class CrmDashboardScreen extends StatelessWidget {
  const CrmDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Team CRM",
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            title: Text("Assigned Investors"),
            subtitle: Text("12 active assignments"),
          ),
          ListTile(
            title: Text("Pending Follow-ups"),
            subtitle: Text("4 due today"),
          ),
          ListTile(
            title: Text("Recent Communication Logs"),
            subtitle: Text("Call with Ali - discussed withdrawal timeline"),
          ),
          ListTile(
            title: Text("Notes"),
            subtitle: Text("Investor prefers monthly update calls"),
          ),
        ],
      ),
    );
  }
}
