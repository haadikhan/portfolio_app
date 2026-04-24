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

class _CurrentReleaseSnapshot {
  const _CurrentReleaseSnapshot({
    required this.versionCode,
    required this.versionName,
  });

  final int versionCode;
  final String versionName;
}

class AdminAppUpdatesScreen extends StatefulWidget {
  const AdminAppUpdatesScreen({super.key});

  @override
  State<AdminAppUpdatesScreen> createState() => _AdminAppUpdatesScreenState();
}

class _AdminAppUpdatesScreenState extends State<AdminAppUpdatesScreen> {
  final _versionName = TextEditingController();
  final _versionCode = TextEditingController();
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
    _versionName.dispose();
    _versionCode.dispose();
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

  Future<_CurrentReleaseSnapshot?> _loadCurrentRelease() async {
    final doc = await FirebaseFirestore.instance
        .collection("app_releases")
        .doc("current_android")
        .get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    if (data["isActive"] != true) return null;
    return _CurrentReleaseSnapshot(
      versionCode: (data["versionCode"] as num?)?.toInt() ?? 0,
      versionName: (data["versionName"] ?? "").toString(),
    );
  }

  Future<_ParsedApkMetadata> _parseApkMetadata({
    required String storagePath,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      "parseInvestorApkMetadata",
    );
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

  Future<bool> _confirmMetadataMismatch({
    required _ParsedApkMetadata parsed,
    required String enteredVersionName,
    required int enteredVersionCode,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr("admin_updates_mismatch_title")),
          content: Text(
            context.trParams("admin_updates_mismatch_body", {
              "parsedName": parsed.versionName,
              "parsedCode": parsed.versionCode.toString(),
              "enteredName": enteredVersionName,
              "enteredCode": enteredVersionCode.toString(),
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.tr("cancel")),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.tr("admin_updates_continue_anyway")),
            ),
          ],
        );
      },
    );
    return ok == true;
  }

  Future<void> _publish() async {
    final bytes = _picked?.bytes;
    final enteredCode = int.tryParse(_versionCode.text.trim());
    final enteredName = _versionName.text.trim();
    final requiredAfterDays = int.tryParse(_requiredAfterDays.text.trim()) ?? 7;
    final versionRequiredMsg = context.tr("admin_updates_version_required");
    final publishCancelledMsg = context.tr("admin_updates_publish_cancelled");
    if (bytes == null || bytes.isEmpty) {
      _snack(context.tr("admin_updates_pick_apk"));
      return;
    }
    if (bytes.length > _kMaxApkBytes) {
      _snack(context.tr("admin_updates_apk_too_large"));
      return;
    }
    if (enteredCode == null || enteredCode <= 0 || enteredName.isEmpty) {
      _snack(versionRequiredMsg);
      return;
    }
    if (requiredAfterDays <= 0 || requiredAfterDays > 365) {
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
      final id = "${DateTime.now().millisecondsSinceEpoch}_${user.uid}";
      final storagePath = "releases/android/uploads/$id.apk";
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
        _versionName.text = parsed.versionName;
        _versionCode.text = parsed.versionCode.toString();
      });

      if (parsed.packageId != _kExpectedInvestorPackage) {
        throw Exception(
          context.trParams("admin_updates_package_mismatch", {
            "expected": _kExpectedInvestorPackage,
            "found": parsed.packageId,
          }),
        );
      }

      final current = await _loadCurrentRelease();
      if (!mounted) return;
      final publishName = _versionName.text.trim();
      final publishCode = int.tryParse(_versionCode.text.trim());
      if (publishCode == null || publishCode <= 0 || publishName.isEmpty) {
        throw Exception(versionRequiredMsg);
      }
      if (publishCode <= (current?.versionCode ?? 0)) {
        final versionNotGreaterMsg = context.trParams(
          "admin_updates_version_not_greater",
          {"current": (current?.versionCode ?? 0).toString()},
        );
        throw Exception(versionNotGreaterMsg);
      }
      final mismatch =
          publishName != parsed.versionName ||
          publishCode != parsed.versionCode;
      if (mismatch) {
        final proceed = await _confirmMetadataMismatch(
          parsed: parsed,
          enteredVersionName: publishName,
          enteredVersionCode: publishCode,
        );
        if (!mounted) return;
        if (!proceed) {
          throw Exception(publishCancelledMsg);
        }
      }
      final apkUrl = await ref.getDownloadURL();
      final now = DateTime.now();
      final historyDocRef = FirebaseFirestore.instance
          .collection("app_releases")
          .doc("android_releases")
          .collection("items")
          .doc(publishCode.toString());
      final currentDocRef = FirebaseFirestore.instance
          .collection("app_releases")
          .doc("current_android");
      final batch = FirebaseFirestore.instance.batch();
      batch.set(historyDocRef, {
        "platform": "android",
        "packageId": parsed.packageId,
        "versionName": publishName,
        "versionCode": publishCode,
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
      batch.set(currentDocRef, {
        "platform": "android",
        "packageId": parsed.packageId,
        "versionName": publishName,
        "versionCode": publishCode,
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
      }, SetOptions(merge: true));
      await batch.commit();

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
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr("admin_updates_subtitle"),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _versionName,
            enabled: !_uploading,
            decoration: InputDecoration(
              labelText: context.tr("admin_updates_version_name"),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _versionCode,
            enabled: !_uploading,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr("admin_updates_version_code"),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _requiredAfterDays,
            enabled: !_uploading,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr("admin_updates_required_after_days"),
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
              final currentCode = (data?["versionCode"] as num?)?.toInt();
              final currentName = (data?["versionName"] ?? "").toString();
              final active = data?["isActive"] == true;
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
