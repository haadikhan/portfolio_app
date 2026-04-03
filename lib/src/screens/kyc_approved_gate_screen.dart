import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../core/i18n/app_translations.dart";
import "../models/app_user.dart";
import "../providers/auth_providers.dart";

class KycApprovedGateScreen extends ConsumerWidget {
  const KycApprovedGateScreen({
    super.key,
    required this.child,
    this.featureName = "feature",
  });

  final Widget child;
  final String featureName;

  static String _featureTr(BuildContext context, String raw) {
    return switch (raw) {
      "portfolio" => context.tr("feat_portfolio"),
      "wallet and withdrawals" => context.tr("feat_wallet"),
      "deposits" => context.tr("feat_deposits"),
      "withdrawals" => context.tr("feat_withdrawals"),
      "reports" => context.tr("feat_reports"),
      "notifications" => context.tr("feat_notifications"),
      _ => raw,
    };
  }

  static String _statusTr(BuildContext context, KycLifecycleStatus s) {
    return switch (s) {
      KycLifecycleStatus.pending => context.tr("kyc_status_name_pending"),
      KycLifecycleStatus.underReview =>
        context.tr("kyc_status_name_underReview"),
      KycLifecycleStatus.approved => context.tr("kyc_status_name_approved"),
      KycLifecycleStatus.rejected => context.tr("kyc_status_name_rejected"),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final kycAsync = ref.watch(userKycProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(child: Text("${context.tr("error_prefix")} $e")),
      ),
      data: (user) {
        final status = user?.kycStatus ?? KycLifecycleStatus.pending;
        if (status == KycLifecycleStatus.approved) return child;
        final reason = kycAsync.valueOrNull?.rejectionReason;
        return Scaffold(
          appBar: AppBar(title: Text(context.tr("kyc_gate_title"))),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 40),
                    const SizedBox(height: 14),
                    Text(
                      context.trParams("kyc_gate_required", {
                        "feature": _featureTr(context, featureName),
                      }),
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status == KycLifecycleStatus.rejected
                          ? context.tr("kyc_gate_rejected")
                          : context.trParams("kyc_gate_status", {
                              "status": _statusTr(context, status),
                            }),
                      textAlign: TextAlign.center,
                    ),
                    if (reason != null && reason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        "${context.tr("kyc_gate_reason")} $reason",
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go("/kyc"),
                      child: Text(context.tr("open_kyc")),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
