import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/i18n/app_translations.dart";
import "../data/app_update_providers.dart";
import "update_action.dart";

class UpdateNoticeHost extends ConsumerWidget {
  const UpdateNoticeHost({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateAsync = ref.watch(appUpdateGateProvider);

    gateAsync.whenData((gate) {
      if (!gate.showGraceBanner) return;
      final shown = ref.read(updatePopupShownThisLaunchProvider);
      if (shown) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final navCtx = navigatorKey.currentContext;
        if (navCtx == null || !navCtx.mounted) return;
        ref.read(updatePopupShownThisLaunchProvider.notifier).state = true;
        await showDialog<void>(
          context: navCtx,
          barrierDismissible: true,
          builder: (ctx) {
            return AlertDialog(
              title: Text(
                gate.release?.title.trim().isNotEmpty == true
                    ? gate.release!.title
                    : navCtx.tr("update_popup_title"),
              ),
              content: Text(
                gate.release?.message.trim().isNotEmpty == true
                    ? gate.release!.message
                    : navCtx.tr("update_popup_body"),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(navCtx.tr("update_later")),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final release = gate.release;
                    if (release == null || !navCtx.mounted) return;
                    await openReleaseUpdate(navCtx, ref, release);
                  },
                  child: Text(navCtx.tr("update_now")),
                ),
              ],
            );
          },
        );
      });
    });

    final gate = gateAsync.valueOrNull;
    if (gate == null || !gate.showGraceBanner) return child;

    return Column(
      children: [
        Material(
          color: Colors.red.shade700,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.system_update_alt, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.trParams("update_banner_days_left", {
                        "days": "${gate.daysLeft}",
                      }),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: gate.release == null
                        ? null
                        : () => openReleaseUpdate(context, ref, gate.release!),
                    child: Text(
                      context.tr("update_now"),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
