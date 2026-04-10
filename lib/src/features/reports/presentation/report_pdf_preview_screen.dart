import "dart:typed_data";

import "package:file_saver/file_saver.dart";
import "package:flutter/foundation.dart"
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import "package:flutter/material.dart";
import "package:pdf/pdf.dart";
import "package:printing/printing.dart";

import "../../../core/i18n/app_translations.dart";

/// Full-screen PDF preview with explicit **Download** and **Print** in the app bar.
class ReportPdfPreviewScreen extends StatefulWidget {
  const ReportPdfPreviewScreen({
    super.key,
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;

  @override
  State<ReportPdfPreviewScreen> createState() => _ReportPdfPreviewScreenState();
}

class _ReportPdfPreviewScreenState extends State<ReportPdfPreviewScreen> {
  bool _isDownloading = false;

  String get _baseName {
    final n = widget.fileName.trim();
    if (n.toLowerCase().endsWith(".pdf")) {
      return n.substring(0, n.length - 4);
    }
    return n.isEmpty ? "report" : n;
  }

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final bytes = widget.bytes;
      final fileName = widget.fileName;
      final base = _baseName;

      Future<bool> trySharePdf() async {
        try {
          await Printing.sharePdf(bytes: bytes, filename: fileName);
          return true;
        } catch (e, st) {
          debugPrint("[report_preview] sharePdf failed: $e\n$st");
          return false;
        }
      }

      Future<bool> tryFileSaver() async {
        try {
          await FileSaver.instance.saveFile(
            name: base,
            bytes: bytes,
            fileExtension: "pdf",
            mimeType: MimeType.pdf,
          );
          return true;
        } catch (e, st) {
          debugPrint("[report_preview] FileSaver.saveFile failed: $e\n$st");
          return false;
        }
      }

      final preferShareFirst = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      if (preferShareFirst) {
        if (await trySharePdf()) return;
        if (await tryFileSaver()) return;
      } else {
        if (await tryFileSaver()) return;
        if (await trySharePdf()) return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr("reports_pdf_failed"))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _print() async {
    await Printing.layoutPdf(
      onLayout: (_) async => widget.bytes,
      name: widget.fileName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr("reports_view_title")),
        actions: [
          IconButton(
            tooltip: context.tr("reports_download_action"),
            onPressed: _isDownloading ? null : _download,
            icon: _isDownloading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
          ),
          IconButton(
            tooltip: context.tr("reports_print"),
            icon: const Icon(Icons.print_outlined),
            onPressed: _print,
          ),
        ],
      ),
      body: PdfPreview(
        build: (PdfPageFormat format) async => widget.bytes,
        allowPrinting: false,
        allowSharing: false,
        canChangePageFormat: false,
        maxPageWidth: 700,
      ),
    );
  }
}
