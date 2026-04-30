import "package:cloud_functions/cloud_functions.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../services/device_fingerprint.dart";
import "../../../services/otp_auth_errors.dart";
import "../../../services/otp_callable_errors.dart";
import "../../../services/otp_service.dart";
import "../data/security_providers.dart";

class SecuritySettingsSection extends ConsumerWidget {
  const SecuritySettingsSection({super.key});

  String _mask(String? phone) {
    final p = (phone ?? "").trim();
    if (p.length < 5) return p.isEmpty ? "-" : p;
    return "${p.substring(0, 3)}••••${p.substring(p.length - 2)}";
  }

  Future<void> _showPhoneVerifyFlow(
    BuildContext context,
    WidgetRef ref,
    UserSecurityState? security,
  ) async {
    final phoneCtrl = TextEditingController(text: security?.verifiedPhone ?? "");
    final otpCtrl = TextEditingController();
    final otp = OtpService(FirebaseAuth.instance);
    final functions = FirebaseFunctions.instanceFor(region: "us-central1");
    String? verificationId;
    int? resendToken;
    String? err;
    bool sending = false;
    bool verifying = false;
    /// True after [OtpCodeSent] or [OtpAutoFilled] (SMS flow started).
    bool pastSendPhase = false;
    /// Seconds before "Send code" can be tapped again (reduces SMS abuse bursts).
    int sendCooldownSec = 0;
    int sendCooldownGen = 0;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          void kickSendCooldown() {
            final gen = ++sendCooldownGen;
            setState(() => sendCooldownSec = 30);
            () async {
              while (ctx.mounted &&
                  sendCooldownSec > 0 &&
                  sendCooldownGen == gen) {
                await Future<void>.delayed(const Duration(seconds: 1));
                if (!ctx.mounted || sendCooldownGen != gen) return;
                setState(() => sendCooldownSec -= 1);
              }
            }();
          }

          Future<void> completeEnrollment(PhoneAuthCredential credential) async {
            setState(() {
              verifying = true;
              err = null;
            });
            try {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                throw StateError("No active user");
              }
              final fp = await currentDeviceFingerprint(user.uid);
              await otp.withTransientPhoneLink(credential, () async {
                await functions
                    .httpsCallable("verifyPhoneAndTrustCurrentDevice")
                    .call(fp.toCallablePayload());
              });
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr("otp_enroll_success"))),
              );
            } on FirebaseAuthException catch (e) {
              if (kDebugMode) {
                debugPrint(
                  "[OTP] verify FirebaseAuthException "
                  "code=${e.code} message=${e.message}",
                );
              }
              if (ctx.mounted) {
                setState(() => err = trFirebasePhoneOtpError(ctx, e));
              }
            } on FirebaseFunctionsException catch (e) {
              if (kDebugMode) {
                debugPrint(
                  "[OTP] verify FirebaseFunctionsException "
                  "code=${e.code} message=${e.message}",
                );
              }
              if (ctx.mounted) {
                setState(
                  () => err = trFirebasePhoneCallableError(ctx, e),
                );
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint("[OTP] verify unexpected error: $e");
              }
              if (ctx.mounted) {
                setState(() => err = context.tr("otp_challenge_generic_error"));
              }
            } finally {
              if (ctx.mounted) setState(() => verifying = false);
            }
          }

          return AlertDialog(
            title: Text(context.tr("otp_enroll_title")),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneCtrl,
                  enabled: !pastSendPhase && !sending && !verifying,
                  decoration: InputDecoration(
                    labelText: context.tr("otp_enroll_phone_label"),
                    hintText: context.tr("otp_enroll_phone_hint"),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                if (verificationId != null) ...[
                  TextField(
                    controller: otpCtrl,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    decoration: InputDecoration(
                      labelText: context.tr("otp_label"),
                      hintText: context.tr("otp_hint"),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                  ),
                ],
                if (err != null) ...[
                  const SizedBox(height: 8),
                  Text(err!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed:
                    (sending || verifying) ? null : () => Navigator.pop(ctx),
                child: Text(context.tr("cancel")),
              ),
              if (!pastSendPhase)
                FilledButton(
                  onPressed: (sending || sendCooldownSec > 0)
                      ? null
                      : () async {
                          final p = phoneCtrl.text.trim();
                          if (!p.startsWith("+") || p.length < 10) {
                            setState(
                              () => err = context.tr("otp_enroll_invalid_phone"),
                            );
                            return;
                          }
                          setState(() {
                            sending = true;
                            err = null;
                          });
                          final res = await otp.sendCode(
                            phoneE164: p,
                            resendToken: resendToken,
                          );
                          if (!ctx.mounted) return;
                          switch (res) {
                            case OtpCodeSent():
                              kickSendCooldown();
                              setState(() {
                                verificationId = res.verificationId;
                                resendToken = res.resendToken;
                                pastSendPhase = true;
                              });
                            case OtpAutoFilled(:final credential):
                              setState(() {
                                pastSendPhase = true;
                              });
                              await completeEnrollment(credential);
                            case OtpFailed():
                              kickSendCooldown();
                              if (kDebugMode) {
                                debugPrint(
                                  "[OTP] send failed code=${res.code} "
                                  "message=${res.message} "
                                  "isAttestation=${res.isAttestationError}",
                                );
                              }
                              final msg = res.isAttestationError
                                  ? context.tr("otp_app_not_authorized")
                                  : (res.message.trim().isNotEmpty
                                      ? res.message
                                      : context.tr(
                                          "otp_send_failed_try_again",
                                        ));
                              setState(() => err = msg);
                          }
                          if (ctx.mounted) setState(() => sending = false);
                        },
                  child: sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          sendCooldownSec > 0
                              ? context
                                  .tr("otp_enroll_send_cooldown")
                                  .replaceAll("%s", "$sendCooldownSec")
                              : context.tr("otp_enroll_send_code"),
                        ),
                )
              else if (verificationId != null)
                FilledButton(
                  onPressed: verifying
                      ? null
                      : () async {
                          final code = otpCtrl.text.trim();
                          if (code.length != 6) {
                            setState(
                              () => err = context.tr("otp_challenge_invalid_code"),
                            );
                            return;
                          }
                          final credential = otp.credentialFor(
                            verificationId: verificationId!,
                            smsCode: code,
                          );
                          await completeEnrollment(credential);
                        },
                  child: verifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.tr("verify_otp")),
                )
              else
                FilledButton(
                  onPressed: verifying
                      ? null
                      : () {
                          setState(() {
                            pastSendPhase = false;
                            err = null;
                            otpCtrl.clear();
                          });
                          kickSendCooldown();
                        },
                  child: verifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.tr("otp_enroll_send_code")),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final security = ref.watch(userSecurityProvider).valueOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr("security_section_title"),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(context.tr("security_section_subtitle")),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                security?.hasVerifiedPhone == true
                    ? context.tr("otp_phone_label_verified")
                    : context.tr("otp_phone_label_unverified"),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    security?.hasVerifiedPhone == true
                        ? _mask(security?.verifiedPhone)
                        : context.tr("otp_no_verified_phone"),
                  ),
                  if (security?.hasVerifiedPhone != true) ...[
                    const SizedBox(height: 2),
                    Text(
                      context.tr("otp_setup_hint"),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                    ),
                  ],
                ],
              ),
              trailing: TextButton(
                onPressed: () => _showPhoneVerifyFlow(context, ref, security),
                child: Text(
                  security?.hasVerifiedPhone == true
                      ? context.tr("otp_change_phone")
                      : context.tr("otp_verify_now_cta"),
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr("trusted_devices_title")),
              subtitle: Text(context.tr("trusted_devices_subtitle")),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push("/profile/trusted-devices"),
            ),
          ],
        ),
      ),
    );
  }
}
