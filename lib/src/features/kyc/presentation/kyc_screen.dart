import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/widgets/app_scaffold.dart";

class KycScreen extends StatelessWidget {
  const KycScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Digital Account Opening (KYC)",
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TextField(decoration: InputDecoration(labelText: "CNIC Number")),
          const TextField(
            decoration: InputDecoration(labelText: "Bank IBAN"),
          ),
          const TextField(
            decoration: InputDecoration(labelText: "Nominee Name"),
          ),
          const SizedBox(height: 12),
          const Text("KYC Status: Pending"),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.go("/legal"),
            child: const Text("Submit KYC"),
          ),
        ],
      ),
    );
  }
}
