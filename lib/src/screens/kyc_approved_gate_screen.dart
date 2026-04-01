import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final kycAsync = ref.watch(userKycProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text("Error: $e"))),
      data: (user) {
        final status = user?.kycStatus ?? KycLifecycleStatus.pending;
        if (status == KycLifecycleStatus.approved) return child;
        final reason = kycAsync.valueOrNull?.rejectionReason;
        return Scaffold(
          appBar: AppBar(title: const Text("Verification required")),
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
                      "KYC approval is required for $featureName.",
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status == KycLifecycleStatus.rejected
                          ? "Your last KYC submission was rejected."
                          : "Your KYC is currently ${status.name}.",
                      textAlign: TextAlign.center,
                    ),
                    if (reason != null && reason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Reason: $reason",
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go("/kyc"),
                      child: const Text("Open KYC"),
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
