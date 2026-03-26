import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/widgets/app_scaffold.dart";

class LegalConsentScreen extends StatefulWidget {
  const LegalConsentScreen({super.key});

  @override
  State<LegalConsentScreen> createState() => _LegalConsentScreenState();
}

class _LegalConsentScreenState extends State<LegalConsentScreen> {
  bool accepted = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Legal & Disclaimer",
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("This is a private investment tracking platform."),
            const Text("Returns are not guaranteed."),
            const Text("Past performance does not guarantee future results."),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: accepted,
              onChanged: (v) => setState(() => accepted = v ?? false),
              title: const Text("I understand and accept the disclaimer."),
            ),
            FilledButton(
              onPressed: accepted ? () => context.go("/investor") : null,
              child: const Text("Continue"),
            ),
          ],
        ),
      ),
    );
  }
}
