import "dart:convert";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:file_picker/file_picker.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:http/http.dart" as http;
import "package:intl/intl.dart";

import "../../core/i18n/app_translations.dart";

const int _kMaxReportPdfBytes = 25 * 1024 * 1024;

/// Upload a PDF to Storage and create a [reports] Firestore row visible to investors (see [userReportsProvider]).
class AdminUploadReportsScreen extends ConsumerStatefulWidget {
  const AdminUploadReportsScreen({super.key});

  @override
  ConsumerState<AdminUploadReportsScreen> createState() =>
      _AdminUploadReportsScreenState();
}

class _AdminUploadReportsScreenState
    extends ConsumerState<AdminUploadReportsScreen> {
  final _title = TextEditingController();
  final _month = TextEditingController();
  final _year = TextEditingController();

  PlatformFile? _picked;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month.text = DateFormat.MMMM().format(n);
    _year.text = "${n.year}";
  }

  @override
  void dispose() {
    _title.dispose();
    _month.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ["pdf"],
      withData: true,
    );
    if (r != null && r.files.isNotEmpty) {
      setState(() => _picked = r.files.single);
    }
  }

  Future<void> _submit() async {
    final bytes = _picked?.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("admin_reports_pick_pdf"))),
      );
      return;
    }
    if (bytes.length > _kMaxReportPdfBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${context.tr("error_prefix")} PDF must be under 25 MB.",
          ),
        ),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("not signed in");
      final authUid = user.uid;
      final token = await user.getIdToken(true);

      final projectId = Firebase.app().options.projectId;
      if (projectId.isEmpty) {
        throw Exception("Missing Firebase project id.");
      }
      final uploadUri = Uri.parse(
        "https://us-central1-$projectId.cloudfunctions.net/uploadInvestorReportHttp",
      );

      final res = await http.post(
        uploadUri,
        body: bytes,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/pdf",
        },
      );
      if (res.statusCode != 200) {
        String detail = res.body;
        try {
          final err = jsonDecode(res.body);
          if (err is Map && err["error"] != null) {
            detail = "${err["error"]}";
          }
        } catch (_) {}
        throw Exception("Upload failed (HTTP ${res.statusCode}): $detail");
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        throw Exception("Invalid upload response.");
      }
      final storagePath = decoded["storagePath"] as String?;
      if (storagePath == null || storagePath.isEmpty) {
        throw Exception("Missing storagePath in response.");
      }

      final url =
          await FirebaseStorage.instance.ref(storagePath).getDownloadURL();

      final titleText = _title.text.trim();
      final yearVal = int.tryParse(_year.text.trim()) ?? DateTime.now().year;

      await FirebaseFirestore.instance.collection("reports").add({
        "title": titleText.isEmpty
            ? "Monthly statement"
            : titleText,
        "month": _month.text.trim(),
        "year": yearVal,
        "fileUrl": url,
        "uid": "all",
        "createdAt": FieldValue.serverTimestamp(),
        "uploadedBy": authUid,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("admin_reports_upload_ok"))),
      );
      setState(() {
        _picked = null;
        _uploading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${context.tr("error_prefix")} $e")),
        );
      }
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr("admin_reports_heading"),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr("admin_reports_subtitle"),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: context.tr("admin_reports_field_title"),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _month,
                  decoration: InputDecoration(
                    labelText: context.tr("admin_reports_field_month"),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _year,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.tr("admin_reports_field_year"),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickFile,
            icon: const Icon(Icons.attach_file),
            label: Text(
              _picked == null
                  ? context.tr("admin_reports_choose_pdf")
                  : context.trParams("admin_reports_selected_file", {
                      "name": _picked!.name,
                    }),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _uploading ? null : _submit,
            icon: _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(context.tr("admin_reports_publish")),
          ),
        ],
      ),
    );
  }
}
