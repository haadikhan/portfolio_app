import "package:flutter/material.dart";

import "../../../core/widgets/app_scaffold.dart";

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Notifications",
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.trending_up),
            title: Text("Profit of PKR 5,000 credited"),
            subtitle: Text("Type: Profit Update"),
          ),
          ListTile(
            leading: Icon(Icons.account_balance_wallet),
            title: Text("Deposit of PKR 100,000 approved"),
            subtitle: Text("Type: Investment Update"),
          ),
          ListTile(
            leading: Icon(Icons.outbox),
            title: Text("Withdrawal request received"),
            subtitle: Text("Type: Withdrawal Status"),
          ),
        ],
      ),
    );
  }
}
