import "package:cloud_firestore/cloud_firestore.dart";
import "package:cloud_functions/cloud_functions.dart";
import "package:file_picker/file_picker.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/material.dart";

import "../../core/i18n/app_translations.dart";

const int _kMaxApkBytes = 200 * 1024 * 1024;
const String _kExpectedInvestorPackage = String.fromEnvironment(
  "INVESTOR_ANDROID_PACKAGE",
  defaultValue: "com.example.portfolio_app",
);

class _ParsedApkMetadata {
  const _ParsedApkMetadata({
    required this.packageId,
    required this.versionName,
    required this.versionCode,
  });

  final String packageId;
  final String versionName;
  final int versionCode;
}

class AdminAppUpdatesScreen extends StatefulWidget {
  const AdminAppUpdatesScreen({super.key});

  @override
  State<AdminAppUpdatesScreen> createState() => _AdminAppUpdatesScreenState();
}

class _AdminAppUpdatesScreenState extends State<AdminAppUpdatesScreen> {
  final _requiredAfterDays = TextEditingController(text: "7");
  final _title = TextEditingController();
  final _message = TextEditingController(
    text: "Please update the app to continue using.",
  );

  PlatformFile? _picked;
  bool _uploading = false;
  bool _active = true;
  int _uploadedBytes = 0;
  int _totalBytes = 0;
  String? _lastError;
  _ParsedApkMetadata? _parsedMetadata;

  @override
  void dispose() {
    _requiredAfterDays.dispose();
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickApk() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ["apk"],
      withData: true,
    );
    if (r != null && r.files.isNotEmpty) {
      setState(() {
        _picked = r.files.single;
        _parsedMetadata = null;
      });
    }
  }

  Future<_ParsedApkMetadata> _parseApkMetadata({
    required String storagePath,
  }) async {
    final fn = FirebaseFunctions.instanceFor(region: "us-central1");
    final callable = fn.httpsCallable("parseInvestorApkMetadata");
    final result = await callable.call(<String, dynamic>{
      "storagePath": storagePath,
    });
    final payload = (result.data as Map<Object?, Object?>)
        .cast<String, dynamic>();
    final packageId = (payload["packageId"] ?? "").toString().trim();
    final versionName = (payload["versionName"] ?? "").toString().trim();
    final versionCode = (payload["versionCode"] as num?)?.toInt() ?? 0;
    if (packageId.isEmpty || versionName.isEmpty || versionCode <= 0) {
      throw Exception("Invalid APK metadata returned by server parser.");
    }
    return _ParsedApkMetadata(
      packageId: packageId,
      versionName: versionName,
      versionCode: versionCode,
    );
  }

  Future<void> _publish() async {
    final bytes = _picked?.bytes;
    final rawDaysText = _requiredAfterDays.text.trim();
    final requiredAfterDays = int.tryParse(rawDaysText) ?? -1;

    if (bytes == null || bytes.isEmpty) {
      _snack(context.tr("admin_updates_pick_apk"));
      return;
    }
    if (bytes.length > _kMaxApkBytes) {
      _snack(context.tr("admin_updates_apk_too_large"));
      return;
    }
    if (requiredAfterDays < 0 || requiredAfterDays > 365) {
      _snack(context.tr("admin_updates_grace_days_invalid"));
      return;
    }

    setState(() {
      _uploading = true;
      _uploadedBytes = 0;
      _totalBytes = bytes.length;
      _lastError = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("not signed in");
      final uploadKey = "${DateTime.now().millisecondsSinceEpoch}_${user.uid}";
      final storagePath = "releases/android/uploads/$uploadKey.apk";
      final ref = FirebaseStorage.instance.ref(storagePath);
      final task = ref.putData(
        bytes,
        SettableMetadata(
          contentType: "application/vnd.android.package-archive",
        ),
      );
      task.snapshotEvents.listen((snapshot) {
        if (!mounted) return;
        setState(() {
          _uploadedBytes = snapshot.bytesTransferred;
          _totalBytes = snapshot.totalBytes > 0
              ? snapshot.totalBytes
              : bytes.length;
        });
      });
      await task;
      final parsed = await _parseApkMetadata(storagePath: storagePath);
      if (!mounted) return;
      setState(() {
        _parsedMetadata = parsed;
      });

      if (parsed.packageId != _kExpectedInvestorPackage) {
        throw Exception(
          context.trParams("admin_updates_package_mismatch", {
            "expected": _kExpectedInvestorPackage,
            "found": parsed.packageId,
          }),
        );
      }

      final apkUrl = await ref.getDownloadURL();
      final now = DateTime.now();
      final currentDocRef = FirebaseFirestore.instance
          .collection("app_releases")
          .doc("current_android");

      await FirebaseFirestore.instance.runTransaction<void>((tx) async {
            final snap = await tx.get(currentDocRef);
            final prev =
                (snap.data()?["releaseGeneration"] as num?)?.toInt() ?? 0;
            final next = prev + 1;
            final historyDocRef = FirebaseFirestore.instance
                .collection("app_releases")
                .doc("android_releases")
                .collection("items")
                .doc("${next}_$uploadKey");

            tx.set(historyDocRef, {
              "platform": "android",
              "releaseGeneration": next,
              "packageId": parsed.packageId,
              "versionName": parsed.versionName,
              "versionCode": parsed.versionCode,
              "parsedVersionName": parsed.versionName,
              "parsedVersionCode": parsed.versionCode,
              "apkStoragePath": storagePath,
              "apkUrl": apkUrl,
              "requiredAfterDays": requiredAfterDays,
              "publishedAt": FieldValue.serverTimestamp(),
              "uploadedAt": FieldValue.serverTimestamp(),
              "title": _title.text.trim(),
              "message": _message.text.trim(),
              "isActive": _active,
              "publishedBy": user.uid,
              "releaseRef": historyDocRef.path,
              "createdAtClient": now.toIso8601String(),
            }, SetOptions(merge: true));

            tx.set(
              currentDocRef,
              {
                "platform": "android",
                "releaseGeneration": next,
                "packageId": parsed.packageId,
                "versionName": parsed.versionName,
                "versionCode": parsed.versionCode,
                "parsedVersionName": parsed.versionName,
                "parsedVersionCode": parsed.versionCode,
                "apkStoragePath": storagePath,
                "apkUrl": apkUrl,
                "requiredAfterDays": requiredAfterDays,
                "publishedAt": FieldValue.serverTimestamp(),
                "title": _title.text.trim(),
                "message": _message.text.trim(),
                "isActive": _active,
                "publishedBy": user.uid,
                "releaseRef": historyDocRef.path,
              },
              SetOptions(merge: true),
            );
          });

      if (!mounted) return;
      _snack(context.tr("admin_updates_publish_ok"));
      setState(() {
        _picked = null;
        _parsedMetadata = null;
        _uploading = false;
        _uploadedBytes = 0;
        _totalBytes = 0;
      });
    } catch (e) {
      if (mounted) {
        _snack("${context.tr("error_prefix")} $e");
      }
      setState(() {
        _uploading = false;
        _lastError = "$e";
      });
    }
  }

  double get _progress {
    if (_totalBytes <= 0) return 0;
    return (_uploadedBytes / _totalBytes).clamp(0, 1);
  }

  String _formatMb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(2);

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr("admin_updates_heading"),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr("admin_updates_subtitle"),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _requiredAfterDays,
            enabled: !_uploading,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr("admin_updates_required_after_days"),
              helperText:
                  context.tr("admin_updates_required_after_days_helper"),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            enabled: !_uploading,
            decoration: InputDecoration(
              labelText: context.tr("admin_updates_title"),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _message,
            enabled: !_uploading,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: context.tr("admin_updates_message"),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_uploading) ...[
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text(
              context.trParams("admin_updates_upload_progress", {
                "uploaded": _formatMb(_uploadedBytes),
                "total": _formatMb(_totalBytes),
                "percent": (_progress * 100).toStringAsFixed(2),
              }),
            ),
            const SizedBox(height: 12),
          ],
          if (_lastError != null && !_uploading) ...[
            Text(
              context.trParams("admin_updates_upload_failed_detail", {
                "detail": _lastError!,
              }),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _publish,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr("admin_updates_retry_upload")),
            ),
            const SizedBox(height: 12),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            onChanged: _uploading ? null : (v) => setState(() => _active = v),
            title: Text(context.tr("admin_updates_active_release")),
          ),
          if (_parsedMetadata != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr("admin_updates_parsed_heading"),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.trParams("admin_updates_parsed_package", {
                      "package": _parsedMetadata!.packageId,
                    }),
                  ),
                  Text(
                    context.trParams("admin_updates_parsed_version", {
                      "name": _parsedMetadata!.versionName,
                      "code": _parsedMetadata!.versionCode.toString(),
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection("app_releases")
                .doc("current_android")
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              if (data == null) return const SizedBox.shrink();

              final currentCode = (data["versionCode"] as num?)?.toInt();
              final currentName = (data["versionName"] ?? "").toString();
              final generation =
                  (data["releaseGeneration"] as num?)?.toInt() ?? 0;
              final active = data["isActive"] == true;

              if (generation > 0) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    context.trParams("admin_updates_current_release_gen", {
                      "name": currentName,
                      "code": (currentCode ?? 0).toString(),
                      "gen": generation.toString(),
                      "active": active ? "true" : "false",
                    }),
                  ),
                );
              }

              if (currentCode == null || currentCode <= 0) {
                return const SizedBox.shrink();
              }
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  context.trParams("admin_updates_current_release", {
                    "name": currentName,
                    "code": currentCode.toString(),
                    "active": active ? "true" : "false",
                  }),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickApk,
            icon: const Icon(Icons.android_rounded),
            label: Text(
              _picked == null
                  ? context.tr("admin_updates_choose_apk")
                  : context.trParams("admin_updates_selected_file", {
                      "name": _picked!.name,
                    }),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _uploading ? null : _publish,
            icon: _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(context.tr("admin_updates_publish")),
          ),
        ],
      ),
    );
  }
}
