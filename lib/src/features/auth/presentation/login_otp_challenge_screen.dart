import "package:cloud_functions/cloud_functions.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../features/security/data/security_providers.dart";
import "../../../services/device_fingerprint.dart";
import "../../../services/otp_auth_errors.dart";
import "../../../services/otp_callable_errors.dart";
import "../../../services/otp_service.dart";

class LoginOtpChallengeScreen extends StatefulWidget {
  const LoginOtpChallengeScreen({super.key, required this.phoneE164});

  final String phoneE164;

  @override
  State<LoginOtpChallengeScreen> createState() => _LoginOtpChallengeScreenState();
}

class _LoginOtpChallengeScreenState extends State<LoginOtpChallengeScreen> {
  final _otpCtrl = TextEditingController();
  final _otpService = OtpService(FirebaseAuth.instance);
  final _functions = FirebaseFunctions.instanceFor(region: "us-central1");
  String? _verificationId;
  int? _resendToken;
  bool _sending = true;
  bool _verifying = false;
  int _cooldown = 30;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sendCode();
    _tick();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _tick() async {
    while (mounted && _cooldown > 0) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _cooldown -= 1);
    }
  }

  Future<void> _sendCode({bool isResend = false}) async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final res = await _otpService.sendCode(
      phoneE164: widget.phoneE164,
      resendToken: isResend ? _resendToken : null,
    );
    if (!mounted) return;
    switch (res) {
      case OtpCodeSent():
        setState(() {
          _verificationId = res.verificationId;
          _resendToken = res.resendToken;
          _sending = false;
          _cooldown = 30;
        });
        _tick();
      case OtpAutoFilled(:final credential):
        await _completeOtp(credential);
      case OtpFailed():
        setState(() {
          _sending = false;
          _error = res.message;
        });
    }
  }

  Future<void> _completeOtp(PhoneAuthCredential credential) async {
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await _otpService.withTransientPhoneLink(credential, () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception("No signed-in user");
        final fp = await currentDeviceFingerprint(user.uid);
        await _functions
            .httpsCallable("markDeviceTrusted")
            .call(fp.toCallablePayload());
      });
      if (!mounted) return;
      ProviderScope.containerOf(context, listen: false)
        ..invalidate(currentDeviceTrustedProvider)
        ..invalidate(otpRequiredProvider);
      if (!mounted) return;
      context.go("/investor");
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = trFirebasePhoneOtpError(context, e);
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = trFirebasePhoneCallableError(context, e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = context.tr("otp_challenge_generic_error"));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _verifyManual() async {
    final id = _verificationId;
    final code = _otpCtrl.text.trim();
    if (id == null || code.length != 6) {
      setState(() => _error = context.tr("otp_challenge_invalid_code"));
      return;
    }
    final cred = _otpService.credentialFor(verificationId: id, smsCode: code);
    await _completeOtp(cred);
  }

  @override
  Widget build(BuildContext context) {
    final masked = widget.phoneE164.length > 5
        ? "${widget.phoneE164.substring(0, 3)}••••${widget.phoneE164.substring(widget.phoneE164.length - 2)}"
        : widget.phoneE164;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr("otp_challenge_title"))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr("otp_challenge_subtitle").replaceAll("%s", masked),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    labelText: context.tr("otp_label"),
                    hintText: context.tr("otp_hint"),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: (_sending || _verifying) ? null : _verifyManual,
                  child: _verifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.tr("otp_challenge_verify")),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: (_cooldown > 0 || _sending || _verifying)
                      ? null
                      : () => _sendCode(isResend: true),
                  child: Text(
                    _cooldown > 0
                        ? context.tr("otp_challenge_resend_in").replaceAll(
                            "%s",
                            "$_cooldown",
                          )
                        : context.tr("otp_challenge_resend"),
                  ),
                ),
                TextButton(
                  onPressed: _verifying
                      ? null
                      : () async {
                          await FirebaseAuth.instance.signOut();
                          if (!context.mounted) return;
                          context.go("/login");
                        },
                  child: Text(context.tr("otp_challenge_wrong_number_logout")),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
