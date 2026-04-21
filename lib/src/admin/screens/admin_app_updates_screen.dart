import "package:cloud_firestore/cloud_firestore.dart";
import "package:file_picker/file_picker.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/material.dart";

import "../../core/i18n/app_translations.dart";

const int _kMaxApkBytes = 200 * 1024 * 1024;

class AdminAppUpdatesScreen extends StatefulWidget {
  const AdminAppUpdatesScreen({super.key});

  @override
  State<AdminAppUpdatesScreen> createState() => _AdminAppUpdatesScreenState();
}

class _AdminAppUpdatesScreenState extends State<AdminAppUpdatesScreen> {
  final _versionName = TextEditingController();
  final _versionCode = TextEditingController();
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

  @override
  void dispose() {
    _versionName.dispose();
    _versionCode.dispose();
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
      setState(() => _picked = r.files.single);
    }
  }

  Future<void> _publish() async {
    final bytes = _picked?.bytes;
    final code = int.tryParse(_versionCode.text.trim());
    final name = _versionName.text.trim();
    if (bytes == null || bytes.isEmpty) {
      _snack(context.tr("admin_updates_pick_apk"));
      return;
    }
    if (bytes.length > _kMaxApkBytes) {
      _snack(context.tr("admin_updates_apk_too_large"));
      return;
    }
    if (code == null || code <= 0 || name.isEmpty) {
      _snack(context.tr("admin_updates_version_required"));
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
      final storagePath = "releases/android/$code/$id.apk";
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
          _totalBytes = snapshot.totalBytes > 0 ? snapshot.totalBytes : bytes.length;
        });
      });
      await task;

      await FirebaseFirestore.instance
          .collection("app_releases")
          .doc("current_android")
          .set({
            "platform": "android",
            "versionName": name,
            "versionCode": code,
            "apkStoragePath": storagePath,
            "requiredAfterDays": 7,
            "publishedAt": FieldValue.serverTimestamp(),
            "title": _title.text.trim(),
            "message": _message.text.trim(),
            "isActive": _active,
            "publishedBy": user.uid,
          }, SetOptions(merge: true));

      if (!mounted) return;
      _snack(context.tr("admin_updates_publish_ok"));
      setState(() {
        _picked = null;
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

  String _formatMb(int bytes) =>
      (bytes / (1024 * 1024)).toStringAsFixed(2);

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
