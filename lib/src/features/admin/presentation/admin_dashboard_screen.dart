import "package:flutter/material.dart";

import "../../../core/widgets/app_scaffold.dart";

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Admin Dashboard",
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Core Controls"),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _ActionCard(title: "Approve KYC"),
              _ActionCard(title: "Approve Deposits"),
              _ActionCard(title: "Process Withdrawals"),
              _ActionCard(title: "Enter Monthly Returns"),
              _ActionCard(title: "Upload Reports"),
            ],
          ),
          const SizedBox(height: 16),
          const Text("Analytics"),
          const ListTile(title: Text("Recorded AUM"), subtitle: Text("PKR 50M")),
          const ListTile(title: Text("Active Users"), subtitle: Text("1,250")),
          const ListTile(
            title: Text("Total Deposits"),
            subtitle: Text("PKR 82M"),
          ),
          const ListTile(
            title: Text("Total Withdrawals"),
            subtitle: Text("PKR 12M"),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        child: ListTile(
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
