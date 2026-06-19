import "dart:typed_data";

import "package:flutter/foundation.dart" show debugPrint;
import "package:flutter/services.dart" show rootBundle;
import "package:intl/intl.dart";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;

import "../../../core/branding/brand_assets.dart";
import "../../../core/formatting/transaction_display.dart";
import "../../investor/data/models/txn_item.dart";

String _pdfTxnId(String id, String type) => formatTransactionId(id, type);

final _redemptionRed = PdfColor.fromHex("#D14343");

final _brandGreen = PdfColor.fromHex("#0F7A2C");
const _white = PdfColors.white;
const _black = PdfColors.black;
final _footerLabelGrey = PdfColor.fromInt(0xFF555555);

/// Accent bar is drawn in [buildBackground], which is anchored at [margin.left].
/// Use a negative left offset to place the bar on the physical page edge.
const _accentLineWidth = 4.0;
const _pageMarginLeft = 40.0;

/// Inclusive date range for filtering [TxnItem.createdAt].
List<TxnItem> filterTxnsInRange(
  List<TxnItem> items,
  DateTime periodStart,
  DateTime periodEndInclusive,
) {
  final a = DateTime(periodStart.year, periodStart.month, periodStart.day);
  final b = DateTime(
    periodEndInclusive.year,
    periodEndInclusive.month,
    periodEndInclusive.day,
    23,
    59,
    59,
    999,
  );
  return items
      .where((t) => !t.createdAt.isBefore(a) && !t.createdAt.isAfter(b))
      .toList()
    ..sort((x, y) => x.createdAt.compareTo(y.createdAt));
}

enum ReportType { fiveMarketDaily, monthlyReturn }

ReportType resolveReportType(List<TxnItem> transactions) {
  final hasFiveMarket = transactions.any((t) {
    final n = (t.note ?? "").toLowerCase();
    return n.contains("five-market daily profit") ||
        n.contains("five_market_daily");
  });
  return hasFiveMarket ? ReportType.fiveMarketDaily : ReportType.monthlyReturn;
}

String _generateRefNumber(String portfolioNumber) {
  if (portfolioNumber.isEmpty) return "AMAPISCPK-000000000";
  return portfolioNumber;
}

String _formatLetterheadDate(DateTime date) {
  return "${date.day.toString().padLeft(2, "0")}/"
      "${date.month.toString().padLeft(2, "0")}/"
      "${date.year}";
}

pw.Widget _buildLetterheadHeader(
  pw.MemoryImage? logo, {
  required String letterheadPortfolioTitle,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              if (logo != null)
                pw.Image(logo, height: 50, fit: pw.BoxFit.contain),
              pw.SizedBox(height: 2),
              pw.Text(
                "ISC - WAI",
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _black,
                ),
              ),
            ],
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Center(
              child: pw.Text(
                letterheadPortfolioTitle,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: _black,
                ),
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            color: _brandGreen,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  "ISC-WAI",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _white,
                  ),
                ),
                pw.Text(
                  "Aitemaad - Shariah Compliant",
                  style: const pw.TextStyle(fontSize: 9, color: _white),
                ),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Container(height: 2, color: _brandGreen),
    ],
  );
}

pw.Widget _footerRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 100,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 7.5, color: _footerLabelGrey),
          ),
        ),
        pw.Text(value, style: pw.TextStyle(fontSize: 7.5, color: _black)),
      ],
    ),
  );
}

pw.Widget _buildLetterheadFooter() {
  return pw.Column(
    children: [
      pw.Container(height: 1, color: _brandGreen),
      pw.SizedBox(height: 6),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _footerRow("Contact Number", "021-34010616"),
                _footerRow("Contact on", "contact@islamicsavingcenter.com"),
                _footerRow(
                  "For Information",
                  "contact@islamicsavingcenter.com",
                ),
                _footerRow("Visit our website", "www.islamicsavingcenter.com"),
              ],
            ),
          ),
          pw.Container(
            width: 1,
            height: 60,
            color: _brandGreen,
            margin: const pw.EdgeInsets.symmetric(horizontal: 12),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Follow us on social media",
                  style: pw.TextStyle(fontSize: 7.5, color: _footerLabelGrey),
                ),
                pw.Text(
                  "@islamicsavingcenter",
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _black,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  "Facebook  Instagram  Twitter  TikTok  LinkedIn  YouTube",
                  style: pw.TextStyle(fontSize: 7.5, color: _footerLabelGrey),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  "Bisma Garden opposite to Darul-Sehat Hospital,",
                  style: pw.TextStyle(fontSize: 7.5, color: _footerLabelGrey),
                ),
                pw.Text(
                  "Gulistan-e-Jauhar, Karachi",
                  style: pw.TextStyle(fontSize: 7.5, color: _footerLabelGrey),
                ),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Container(
        width: double.infinity,
        color: _brandGreen,
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.Center(
          child: pw.Text(
            "ISC-WAI",
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _white,
            ),
          ),
        ),
      ),
    ],
  );
}

pw.Widget _buildPageBackground(pw.MemoryImage? logo) {
  return pw.Stack(
    children: [
      if (logo != null)
        pw.Positioned.fill(
          child: pw.Center(
            child: pw.Opacity(
              opacity: 0.05,
              child: pw.Image(logo, width: 250, fit: pw.BoxFit.contain),
            ),
          ),
        ),
      pw.Positioned(
        left: -_pageMarginLeft,
        top: 0,
        bottom: 0,
        child: pw.Container(width: _accentLineWidth, color: _brandGreen),
      ),
    ],
  );
}

/// Localized labels for PDF columns and sections (pass [context.tr] values from UI).
class ReportPdfLabels {
  const ReportPdfLabels({
    required this.documentTitle,
    required this.headerAccountTitle,
    required this.headerPortfolioNo,
    required this.headerReportType,
    required this.reportTypeFiveMarket,
    required this.reportTypeMonthly,
    required this.period,
    required this.summary,
    required this.colTxnId,
    required this.colDate,
    required this.colType,
    required this.colStatus,
    required this.colAmount,
    required this.colNote,
    required this.totalDeposits,
    required this.totalWithdrawals,
    required this.totalProfit,
    required this.totalManagementFees,
    required this.footer,
    required this.transactionsHeading,
    required this.letterheadPortfolioTitle,
  });

  final String documentTitle;
  final String headerAccountTitle;
  final String headerPortfolioNo;
  final String headerReportType;
  final String reportTypeFiveMarket;
  final String reportTypeMonthly;
  final String period;
  final String summary;
  final String colTxnId;
  final String colDate;
  final String colType;
  final String colStatus;
  final String colAmount;
  final String colNote;
  final String totalDeposits;
  final String totalWithdrawals;
  final String totalProfit;
  final String totalManagementFees;
  final String footer;
  final String transactionsHeading;
  final String letterheadPortfolioTitle;
}

pw.Widget _reportHeaderTable({
  required ReportPdfLabels labels,
  required String accountTitle,
  required String portfolioNumber,
  required ReportType reportType,
}) {
  final reportTypeLabel = reportType == ReportType.fiveMarketDaily
      ? labels.reportTypeFiveMarket
      : labels.reportTypeMonthly;
  final labelStyle = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
  final valueStyle = pw.TextStyle(fontSize: 9);

  pw.Widget headerCell(
    String text, {
    pw.Alignment align = pw.Alignment.centerLeft,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Align(
        alignment: align,
        child: pw.Text(text, style: labelStyle),
      ),
    );
  }

  pw.Widget valueCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(text, style: valueStyle),
      ),
    );
  }

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    columnWidths: {
      0: const pw.FlexColumnWidth(2),
      1: const pw.FlexColumnWidth(3),
    },
    children: [
      pw.TableRow(
        children: [
          headerCell(labels.headerAccountTitle),
          valueCell(accountTitle),
        ],
      ),
      pw.TableRow(
        children: [
          headerCell(labels.headerPortfolioNo),
          valueCell(portfolioNumber),
        ],
      ),
      pw.TableRow(
        children: [
          headerCell(labels.headerReportType),
          valueCell(reportTypeLabel),
        ],
      ),
    ],
  );
}

String _pdfNoteCell(TxnItem t) {
  final noteRaw = t.note?.trim();
  var displayNote = displayTransactionNote(
    (noteRaw == null || noteRaw.isEmpty) ? null : noteRaw,
  );
  // PDF standard fonts may not render the Unicode em dash reliably.
  if (displayNote == "\u2014") {
    displayNote = "-";
  }
  return displayNote.length > 50
      ? "${displayNote.substring(0, 47)}..."
      : displayNote;
}

pw.Widget _buildTransactionsLedgerTable({
  required List<TxnItem> transactions,
  required DateFormat dateTimeFmt,
  required ReportPdfLabels labels,
}) {
  final headerStyle = pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold);
  const cellStyle = pw.TextStyle(fontSize: 7);

  final columnWidths = <int, pw.TableColumnWidth>{
    0: const pw.FixedColumnWidth(130),
    1: const pw.FixedColumnWidth(70),
    2: const pw.FixedColumnWidth(70),
    3: const pw.FixedColumnWidth(55),
    4: const pw.FixedColumnWidth(55),
    5: const pw.FlexColumnWidth(),
  };

  return pw.TableHelper.fromTextArray(
    headers: [
      labels.colTxnId,
      labels.colDate,
      labels.colType,
      labels.colStatus,
      labels.colAmount,
      labels.colNote,
    ],
    data: transactions
        .map(
          (t) => [
            _pdfTxnId(t.id, t.type),
            dateTimeFmt.format(t.createdAt),
            displayTransactionType(t.type),
            displayTransactionStatus(t.status),
            t.amount.toStringAsFixed(2),
            _pdfNoteCell(t),
          ],
        )
        .toList(),
    headerStyle: headerStyle,
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
    cellStyle: cellStyle,
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    cellAlignments: const {
      0: pw.Alignment.centerLeft,
      1: pw.Alignment.centerLeft,
      2: pw.Alignment.centerLeft,
      3: pw.Alignment.centerLeft,
      4: pw.Alignment.centerRight,
      5: pw.Alignment.centerLeft,
    },
    columnWidths: columnWidths,
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
    textStyleBuilder: (index, cell, rowNum) {
      if (index != 2) return null;
      final txnIndex = rowNum - 1;
      if (txnIndex < 0 || txnIndex >= transactions.length) return null;
      final ty = transactions[txnIndex].type;
      if (isRedemptionType(ty) || isFeeType(ty)) {
        return pw.TextStyle(fontSize: 7, color: _redemptionRed);
      }
      return null;
    },
  );
}

/// Builds a multi-page A4 PDF; returns bytes for [Printing.layoutPdf].
Future<Uint8List> buildInvestorReportPdf({
  required String accountLabel,
  required String portfolioNumber,
  required ReportType reportType,
  required DateTime periodStart,
  required DateTime periodEndInclusive,
  required List<TxnItem> transactions,
  required ReportPdfLabels labels,
  required bool isYearlyReport,
}) async {
  pw.MemoryImage? logoImage;
  try {
    final logoBytes = (await rootBundle.load(
      BrandAssets.logoGreenPng,
    )).buffer.asUint8List();
    logoImage = pw.MemoryImage(logoBytes);
  } catch (e) {
    debugPrint("[reports] Logo load failed: $e");
  }

  final dateFmt = DateFormat.yMMMd();
  final dateTimeFmt = DateFormat.yMMMd().add_Hm();
  final refNumber = _generateRefNumber(portfolioNumber);
  final letterheadDate = _formatLetterheadDate(DateTime.now());

  double totalDep = 0;
  double totalWdr = 0;
  double totalPr = 0;
  double totalMgmtFee = 0;
  for (final t in transactions) {
    final st = t.status;
    final ty = t.type;
    if (ty == "deposit" && st == "approved") {
      totalDep += t.amount;
    } else if (ty == "withdrawal" && (st == "approved" || st == "completed")) {
      totalWdr += t.amount;
    } else if ((ty == "profit" || ty == "profit_entry") &&
        (st == "approved" || st == "completed")) {
      totalPr += t.amount;
    } else if (ty == "management_fee" &&
        (st == "approved" || st == "completed")) {
      totalMgmtFee += t.amount.abs();
    }
  }

  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        buildBackground: (_) => _buildPageBackground(logoImage),
      ),
      header: (_) => pw.Column(
        children: [
          _buildLetterheadHeader(
            logoImage,
            letterheadPortfolioTitle: labels.letterheadPortfolioTitle,
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Ref #: $refNumber",
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    "Date: $letterheadDate",
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
        ],
      ),
      footer: (_) => _buildLetterheadFooter(),
      build: (ctx) => [
        pw.Header(
          level: 0,
          child: pw.Text(
            labels.documentTitle,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 12),
        _reportHeaderTable(
          labels: labels,
          accountTitle: accountLabel,
          portfolioNumber: portfolioNumber,
          reportType: reportType,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          "${labels.period}: ${dateFmt.format(periodStart)} - ${dateFmt.format(periodEndInclusive)}",
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          labels.summary,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.Bullet(
          text: "${labels.totalDeposits}: ${totalDep.toStringAsFixed(2)}",
        ),
        pw.Bullet(
          text: "${labels.totalWithdrawals}: ${totalWdr.toStringAsFixed(2)}",
        ),
        pw.Bullet(text: "${labels.totalProfit}: ${totalPr.toStringAsFixed(2)}"),
        if (isYearlyReport)
          pw.Bullet(
            text:
                "${labels.totalManagementFees}: "
                "${totalMgmtFee.toStringAsFixed(2)}",
          ),
        if (isYearlyReport)
          pw.Bullet(
            text:
                "Management fees for this period are "
                "included in this annual report. "
                "See Fee Statements section for "
                "a detailed annual fee breakdown.",
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
        pw.SizedBox(height: 16),
        pw.Text(
          labels.transactionsHeading,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        if (transactions.isEmpty)
          pw.Text("-")
        else
          _buildTransactionsLedgerTable(
            transactions: transactions,
            dateTimeFmt: dateTimeFmt,
            labels: labels,
          ),
        pw.SizedBox(height: 24),
        pw.Text(
          labels.footer,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
    ),
  );

  return pdf.save();
}
