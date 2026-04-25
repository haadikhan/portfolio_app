import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/i18n/app_translations.dart";
import "../data/app_update_providers.dart";
import "update_action.dart";

class ForceUpdateScreen extends ConsumerStatefulWidget {
  const ForceUpdateScreen({super.key});

  @override
  ConsumerState<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends ConsumerState<ForceUpdateScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _openUpdate(AppReleaseInfo release) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await openReleaseUpdate(context, ref, release);
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.tr("update_failed_retry"));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(stableAppUpdateGateProvider).valueOrNull;
    final release = gate?.release;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.system_update_alt_rounded, size: 54),
                const SizedBox(height: 18),
                Text(
                  context.tr("update_required_title"),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  release?.message.trim().isNotEmpty == true
                      ? release!.message
                      : context.tr("update_required_body"),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (gate != null && release != null)
                  Text(
                    context.trParams("update_version_info", {
                      "installed": gate.installedVersionName,
                      "required": release.versionName,
                    }),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 22),
                if (_busy)
                  Column(
                    children: [
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(context.tr("downloading_update")),
                    ],
                  ),
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton.icon(
                  onPressed: release == null || _busy
                      ? null
                      : () => _openUpdate(release),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(context.tr("update_now")),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
