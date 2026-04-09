import "dart:typed_data";

import "package:file_saver/file_saver.dart";
import "package:flutter/material.dart";
import "package:pdf/pdf.dart";
import "package:printing/printing.dart";

import "../../../core/i18n/app_translations.dart";

/// Full-screen PDF preview with explicit **Download** and **Print** in the app bar.
class ReportPdfPreviewScreen extends StatelessWidget {
  const ReportPdfPreviewScreen({
    super.key,
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;

  String get _baseName {
    final n = fileName.trim();
    if (n.toLowerCase().endsWith(".pdf")) {
      return n.substring(0, n.length - 4);
    }
    return n.isEmpty ? "report" : n;
  }

  Future<void> _download(BuildContext context) async {
    try {
      await FileSaver.instance.saveFile(
        name: _baseName,
        bytes: bytes,
        fileExtension: "pdf",
        mimeType: MimeType.pdf,
      );
    } catch (_) {
      try {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
        return;
      } catch (_) {}
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr("reports_pdf_failed"))),
        );
      }
    }
  }

  Future<void> _print(BuildContext context) async {
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: fileName,
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
            icon: const Icon(Icons.download_outlined),
            onPressed: () => _download(context),
          ),
          IconButton(
            tooltip: context.tr("reports_print"),
            icon: const Icon(Icons.print_outlined),
            onPressed: () => _print(context),
          ),
        ],
      ),
      body: PdfPreview(
        build: (PdfPageFormat format) async => bytes,
        allowPrinting: false,
        allowSharing: false,
        canChangePageFormat: false,
        maxPageWidth: 700,
      ),
    );
  }
}
