import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:go_router/go_router.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_scaffold.dart";

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: context.tr("otp_registration_title"),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr("phone_number")),
            TextField(
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(hintText: context.tr("phone_hint")),
            ),
            const SizedBox(height: 12),
            Text(context.tr("otp_label")),
            TextField(
              decoration: InputDecoration(hintText: context.tr("otp_hint")),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go("/kyc"),
              child: Text(context.tr("verify_otp")),
            ),
          ],
        ),
      ),
    );
  }
}
