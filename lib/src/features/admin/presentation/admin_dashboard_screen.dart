import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/widgets/app_scaffold.dart";

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Admin Dashboard",
      showNotificationAction: false,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Core Controls"),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ActionCard(
                title: "Finance console",
                subtitle: "Deposits, withdrawals, ledger, postings",
                onTap: () => context.push("/admin/finance"),
              ),
              _ActionCard(
                title: "Apply returns",
                subtitle: "Monthly profit distribution to portfolios",
                onTap: () => context.push("/admin/apply-return"),
              ),
              const _ActionCard(title: "Approve KYC"),
              const _ActionCard(title: "Upload Reports"),
            ],
          ),
          const SizedBox(height: 16),
          const Text("Analytics"),
          const ListTile(
            title: Text("Recorded AUM"),
            subtitle: Text("PKR 50M"),
          ),
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
  const _ActionCard({required this.title, this.subtitle, this.onTap});
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: ListTile(
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle!) : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
