import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:intl_phone_field/intl_phone_field.dart";
import "package:intl_phone_field/phone_number.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_scaffold.dart";

String _authNationalDigitsForIntlField(String stored) {
  final t = stored.trim().replaceAll(" ", "");
  if (t.isEmpty) return "";
  if (t.startsWith("+")) {
    try {
      return PhoneNumber.fromCompleteNumber(completeNumber: t).number;
    } catch (_) {
      if (t.startsWith("+92")) return t.substring(3);
      return t.replaceFirst(RegExp(r"^\+\d{1,4}"), "");
    }
  }
  return t.replaceAll(RegExp(r"\D"), "");
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: context.tr("otp_registration_title"),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IntlPhoneField(
              initialCountryCode: "PK",
              initialValue: _authNationalDigitsForIntlField(_phoneCtrl.text),
              decoration: InputDecoration(
                labelText: context.tr("phone_hint"),
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: scheme.primary, width: 2),
                ),
              ),
              keyboardType: TextInputType.phone,
              invalidNumberMessage: context.tr("mobile_invalid"),
              onChanged: (phone) {
                _phoneCtrl.text = phone.completeNumber;
              },
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
