import "package:flutter/material.dart";

import "../../../core/widgets/app_scaffold.dart";

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Reports Center",
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            title: Text("Monthly Statement - Jan 2026"),
            subtitle: Text("Includes opening/closing balance and disclaimer."),
            trailing: Icon(Icons.download),
          ),
          const ListTile(
            title: Text("Portfolio Summary"),
            subtitle: Text("Total investment, current value, return %."),
            trailing: Icon(Icons.picture_as_pdf),
          ),
          const ListTile(
            title: Text("Transaction Report"),
            subtitle: Text("Full ledger visibility for audit/disputes."),
            trailing: Icon(Icons.list_alt),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {},
            child: const Text("Trigger Monthly Auto-Generation (Stub)"),
          ),
        ],
      ),
    );
  }
}
