import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/widgets/app_scaffold.dart";

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "OTP Registration",
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Phone Number"),
            const TextField(
              decoration: InputDecoration(hintText: "+92 300 0000000"),
            ),
            const SizedBox(height: 12),
            const Text("OTP"),
            const TextField(decoration: InputDecoration(hintText: "123456")),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go("/kyc"),
              child: const Text("Verify OTP"),
            ),
          ],
        ),
      ),
    );
  }
}
