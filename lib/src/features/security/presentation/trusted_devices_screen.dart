import "package:cloud_functions/cloud_functions.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../providers/auth_providers.dart";
import "../../../providers/mpin_providers.dart";
import "../../mpin/presentation/mpin_prompt_dialog.dart";
import "../data/security_providers.dart";

class TrustedDevicesScreen extends ConsumerWidget {
  const TrustedDevicesScreen({super.key});

  String _revokeErrorMessage(BuildContext context, FirebaseFunctionsException e) {
    final raw = e.message?.trim() ?? "";
    switch (raw) {
      case "MPIN_WRONG":
        return context.tr("mpin_wrong");
      case "MPIN_LOCKED":
        return context.tr("mpin_locked_short");
      case "MPIN_INVALID_FORMAT":
        return context.tr("mpin_invalid_format");
      default:
        return raw.isNotEmpty
            ? raw
            : context.tr("trusted_device_revoke_error");
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(trustedDevicesStreamProvider);
    final currentFp = ref.watch(currentDeviceFingerprintProvider).valueOrNull;

    ref.listen<AsyncValue<bool>>(currentDeviceRevokedProvider, (_, next) async {
      final revoked = next.valueOrNull ?? false;
      if (!revoked || !context.mounted) return;
      await ref.read(authControllerProvider.notifier).logout();
      if (context.mounted) context.go("/login");
    });

    return Scaffold(
      appBar: AppBar(title: Text(context.tr("trusted_devices_title"))),
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "${context.tr("error_prefix")} $e",
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (devices) {
          if (devices.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  context.tr("trusted_devices_empty"),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: devices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final d = devices[index];
              final isCurrent = currentFp?.deviceHash == d.deviceHash;
              return Card(
                child: ListTile(
                  title: Text(
                    d.deviceName.isNotEmpty ? d.deviceName : d.platform,
                  ),
                  subtitle: Text(
                    "${context.tr("trusted_device_last_seen")}: ${d.lastSeenAt?.toLocal() ?? "-"}",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.blue.withValues(alpha: 0.15),
                          ),
                          child: Text(context.tr("trusted_device_current")),
                        ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _revokeDevice(
                          context,
                          ref,
                          d.deviceHash,
                          isCurrent,
                        ),
                        child: Text(context.tr("trusted_device_revoke")),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _revokeDevice(
    BuildContext context,
    WidgetRef ref,
    String deviceHash,
    bool isCurrentDevice,
  ) async {
    final mpinStatus = ref.read(mpinStatusStreamProvider).value;
    final hasMpin =
        mpinStatus?.hasMpin == true && mpinStatus?.enabled == true;

    String? mpin;

    if (hasMpin) {
      if (!context.mounted) return;
      var mpinSubtitle = context.tr("trusted_device_revoke_mpin_subtitle");
      if (isCurrentDevice) {
        mpinSubtitle =
            "$mpinSubtitle\n\n${context.tr("trusted_device_revoke_current_warning")}";
      }
      mpin = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => MpinPromptDialog(subtitleOverride: mpinSubtitle),
      );
      if (!context.mounted) return;
      if (mpin == null) return;
    } else {
      if (!context.mounted) return;
      var body = context.tr("trusted_device_revoke_confirm_body");
      if (isCurrentDevice) {
        body =
            "$body\n\n${context.tr("trusted_device_revoke_current_warning")}";
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.tr("trusted_device_revoke_confirm_title")),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.tr("cancel")),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(context.tr("trusted_device_revoke_confirm_btn")),
            ),
          ],
        ),
      );
      if (!context.mounted) return;
      if (confirmed != true) return;
    }

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: "us-central1",
      ).httpsCallable("removeTrustedDevice");
      await callable.call(<String, dynamic>{
        "deviceHash": deviceHash,
        if (mpin != null) "mpin": mpin,
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("trusted_device_revoked_success"))),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_revokeErrorMessage(context, e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}
