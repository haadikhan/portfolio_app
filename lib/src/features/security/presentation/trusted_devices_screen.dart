import "package:cloud_functions/cloud_functions.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/i18n/app_translations.dart";
import "../data/security_providers.dart";

class TrustedDevicesScreen extends ConsumerWidget {
  const TrustedDevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(trustedDevicesStreamProvider);
    final currentFp = ref.watch(currentDeviceFingerprintProvider).valueOrNull;
    final callable = FirebaseFunctions.instanceFor(
      region: "us-central1",
    ).httpsCallable("removeTrustedDevice");

    return Scaffold(
      appBar: AppBar(title: Text(context.tr("trusted_devices_title"))),
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("${context.tr("error_prefix")} $e")),
        data: (devices) {
          if (devices.isEmpty) {
            return Center(child: Text(context.tr("trusted_devices_empty")));
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
                        onPressed: () async {
                          try {
                            await callable.call({"deviceHash": d.deviceHash});
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.tr("trusted_device_revoked")),
                              ),
                            );
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.tr("trusted_device_revoke_failed"),
                                ),
                              ),
                            );
                          }
                        },
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
}
