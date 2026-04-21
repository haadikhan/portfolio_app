import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../core/i18n/app_translations.dart";
import "../data/app_update_providers.dart";

Future<void> openReleaseUpdate(
  BuildContext context,
  WidgetRef ref,
  AppReleaseInfo release,
) async {
  final url = await ref.read(resolvedApkDownloadUrlProvider(release).future);
  if (url == null || url.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("update_failed_retry"))),
      );
    }
    return;
  }

  final launched = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!context.mounted) return;
  if (!launched) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr("update_failed_retry"))),
    );
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.tr("install_update"))),
  );
}
