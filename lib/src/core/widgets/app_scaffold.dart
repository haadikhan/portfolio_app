import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      body: body,
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(child: Text("Wakalat Invest")),
            _item(context, "Auth", "/auth"),
            _item(context, "KYC", "/kyc"),
            _item(context, "Legal Consent", "/legal"),
            _item(context, "Investor Dashboard", "/investor"),
            _item(context, "Wallet Ledger", "/wallet-ledger"),
            _item(context, "Reports", "/reports"),
            _item(context, "Notifications", "/notifications"),
            _item(context, "Admin Panel", "/admin"),
            _item(context, "CRM Panel", "/crm"),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, String label, String route) {
    return ListTile(
      title: Text(label),
      onTap: () {
        context.pop();
        context.go(route);
      },
    );
  }
}
