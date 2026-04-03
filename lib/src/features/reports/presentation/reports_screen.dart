import "package:flutter/material.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_scaffold.dart";

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: context.tr("reports_center_title"),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text(context.tr("reports_monthly_title")),
            subtitle: Text(context.tr("reports_monthly_subtitle")),
            trailing: const Icon(Icons.download),
          ),
          ListTile(
            title: Text(context.tr("reports_portfolio_title")),
            subtitle: Text(context.tr("reports_portfolio_subtitle")),
            trailing: const Icon(Icons.picture_as_pdf),
          ),
          ListTile(
            title: Text(context.tr("reports_tx_title")),
            subtitle: Text(context.tr("reports_tx_subtitle")),
            trailing: const Icon(Icons.list_alt),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {},
            child: Text(context.tr("reports_stub_button")),
          ),
        ],
      ),
    );
  }
}
