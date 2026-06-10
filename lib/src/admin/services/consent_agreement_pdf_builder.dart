import "dart:typed_data";

import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;

/// Inputs for a consent record PDF: agreement text plus acceptance proof.
class ConsentAgreementPdfInput {
  const ConsentAgreementPdfInput({
    required this.documentTitle,
    required this.agreementParagraphs,
    required this.userId,
    required this.agreementVersion,
    required this.acceptedAtLabel,
    required this.appVersion,
    required this.deviceName,
    required this.platform,
    required this.deviceHash,
  });

  final String documentTitle;
  final List<String> agreementParagraphs;
  final String userId;
  final String agreementVersion;
  final String acceptedAtLabel;
  final String appVersion;
  final String deviceName;
  final String platform;
  final String deviceHash;
}

pw.Widget _proofRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 130,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ),
        pw.Expanded(
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    ),
  );
}

/// Builds an A4 PDF with the legal agreement body and stored acceptance proof.
Future<Uint8List> buildConsentAgreementPdf(ConsentAgreementPdfInput input) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (_) => [
        pw.Text(
          input.documentTitle,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 16),
        for (final paragraph in input.agreementParagraphs) ...[
          pw.Text(
            paragraph,
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 4),
          ),
          pw.SizedBox(height: 10),
        ],
        pw.SizedBox(height: 20),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 12),
        pw.Text(
          "Acceptance Record",
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        _proofRow("Investor UID", input.userId),
        _proofRow("Agreement Version", input.agreementVersion),
        _proofRow("Date & Time", input.acceptedAtLabel),
        _proofRow("App Version", input.appVersion),
        _proofRow("Device", input.deviceName),
        _proofRow("Platform", input.platform),
        _proofRow("Device ID", input.deviceHash),
      ],
    ),
  );

  return pdf.save();
}
