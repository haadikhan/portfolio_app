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
final _pdfAmountFmt = NumberFormat("#,##0.00", "en_US");

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
    required this.colDescription,
    required this.colStatus,
    required this.colDebit,
    required this.colCredit,
    required this.colBalance,
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
  final String colDescription;
  final String colStatus;
  final String colDebit;
  final String colCredit;
  final String colBalance;
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

String _titleCaseWords(String s) {
  if (s.isEmpty) return s;
  return s
      .split(RegExp(r"\s+"))
      .map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1).toLowerCase();
      })
      .join(" ");
}

String _pdfDescriptionCell(TxnItem t) {
  final type = t.type.toLowerCase();
  final amount = t.amount;

  switch (type) {
    case "deposit":
      return "Investment Capital Deposit Received";
    case "withdrawal":
      return "Client Redemption Processed";
    case "profit":
    case "profit_entry":
      if (amount < 0) return "Portfolio Loss Adjustment (Realized)";
      return "Net Realized Profit Credited";
    case "management_fee":
      return "Management Fee Charged";
    case "performance_fee":
      return "Performance Fee Charged";
    case "front_end_load_fee":
      return "Front-End Processing Fee Charged";
    case "referral_fee":
      return "Referral Commission Charged";
    case "adjustment":
      return amount >= 0
          ? "Portfolio Adjustment Credited"
          : "Portfolio Adjustment Debited";
    default:
      if (type.contains("fee")) return "Operational Fee Charged";
      return _titleCaseWords(t.type.replaceAll("_", " "));
  }
}

/// Returns true if this transaction is a CREDIT (increases portfolio value).
bool _isCredit(TxnItem t) {
  final type = t.type.toLowerCase();
  final amount = t.amount;
  switch (type) {
    case "deposit":
      return true;
    case "withdrawal":
      return false;
    case "profit":
    case "profit_entry":
      return amount >= 0;
    case "adjustment":
      return amount >= 0;
    default:
      return false;
  }
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

  // Prefix profit/loss transactions with a clear
  // credited/debited label in the note column.
  final isProfitType =
      t.type.toLowerCase() == "profit" ||
      t.type.toLowerCase() == "profit_entry";
  if (isProfitType) {
    final prefix = t.amount < 0
        ? "Portfolio Loss Adjustment"
        : "Net Realized Profit";
    displayNote = (displayNote == "-" || displayNote.isEmpty)
        ? prefix
        : "$prefix - $displayNote";
  }

  return displayNote.length > 50
      ? "${displayNote.substring(0, 47)}..."
      : displayNote;
}

pw.Widget _buildNote(String number, String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 20,
          child: pw.Text(
            number,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            text,
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey800,
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildTransactionsLedgerTable({
  required List<TxnItem> transactions,
  required DateFormat dateTimeFmt,
  required ReportPdfLabels labels,
  required double openingBalance,
}) {
  final headerStyle = pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold);
  const cellStyle = pw.TextStyle(fontSize: 7);

  final runningBalances = <double>[];
  var balance = openingBalance;
  for (final t in transactions) {
    if (_isCredit(t)) {
      balance += t.amount.abs();
    } else {
      balance -= t.amount.abs();
    }
    runningBalances.add(balance);
  }

  final columnWidths = <int, pw.TableColumnWidth>{
    0: const pw.FixedColumnWidth(90),
    1: const pw.FixedColumnWidth(58),
    2: const pw.FlexColumnWidth(2),
    3: const pw.FixedColumnWidth(48),
    4: const pw.FixedColumnWidth(65),
    5: const pw.FixedColumnWidth(65),
    6: const pw.FixedColumnWidth(70),
    7: const pw.FlexColumnWidth(1),
  };

  final data = <List<String>>[];
  for (var i = 0; i < transactions.length; i++) {
    final t = transactions[i];
    data.add([
      _pdfTxnId(t.id, t.type),
      dateTimeFmt.format(t.createdAt),
      _pdfDescriptionCell(t),
      displayTransactionStatus(t.status),
      _isCredit(t) ? "" : _pdfAmountFmt.format(t.amount.abs()),
      _isCredit(t) ? _pdfAmountFmt.format(t.amount.abs()) : "",
      _pdfAmountFmt.format(runningBalances[i]),
      _pdfNoteCell(t),
    ]);
  }

  return pw.TableHelper.fromTextArray(
    headers: [
      labels.colTxnId,
      labels.colDate,
      labels.colDescription,
      labels.colStatus,
      labels.colDebit,
      labels.colCredit,
      labels.colBalance,
      labels.colNote,
    ],
    data: data,
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
      5: pw.Alignment.centerRight,
      6: pw.Alignment.centerRight,
      7: pw.Alignment.centerLeft,
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
  double totalFrontEndFee = 0;
  double totalPerfFee = 0;
  double totalReferralFee = 0;
  double totalOtherFees = 0;
  for (final t in transactions) {
    final st = t.status;
    final ty = t.type.toLowerCase();
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
    } else if (ty == "front_end_load_fee" &&
        (st == "approved" || st == "completed")) {
      totalFrontEndFee += t.amount.abs();
    } else if (ty == "performance_fee" &&
        (st == "approved" || st == "completed")) {
      totalPerfFee += t.amount.abs();
    } else if (ty == "referral_fee" &&
        (st == "approved" || st == "completed")) {
      totalReferralFee += t.amount.abs();
    } else if (ty != "management_fee" &&
        isFeeType(ty) &&
        (st == "approved" || st == "completed")) {
      totalOtherFees += t.amount.abs();
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
          text:
              "Total Capital Deposits Received: "
              "${_pdfAmountFmt.format(totalDep)}",
        ),
        pw.Bullet(
          text:
              "Total Client Redemptions Processed: "
              "(${_pdfAmountFmt.format(totalWdr.abs())})",
        ),
        pw.Bullet(
          text: totalPr >= 0
              ? "Net Realized Profit Credited: "
                  "${_pdfAmountFmt.format(totalPr)}"
              : "Portfolio Loss Adjustment: "
                  "(${_pdfAmountFmt.format(totalPr.abs())})",
        ),
        if (isYearlyReport)
          pw.Bullet(
            text:
                "Total Management Fees Charged: "
                "(${_pdfAmountFmt.format(totalMgmtFee)})",
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
            openingBalance: 0.0,
          ),
        pw.SizedBox(height: 24),
        pw.Text(
          labels.footer,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
    ),
  );

  if (transactions.isNotEmpty) {
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          buildBackground: (_) => _buildPageBackground(logoImage),
        ),
        header: (_) => _buildLetterheadHeader(
          logoImage,
          letterheadPortfolioTitle: labels.letterheadPortfolioTitle,
        ),
        footer: (_) => _buildLetterheadFooter(),
        build: (ctx) => [
          pw.Text(
            "Annual Portfolio Performance Summary",
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            "Period: ${dateFmt.format(periodStart)} "
            "- ${dateFmt.format(periodEndInclusive)}",
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: [
              "Description",
              "Amount (PKR)",
            ],
            data: [
              ["Opening Portfolio Balance", _pdfAmountFmt.format(0.0)],
              [
                "Total Capital Deposits Received",
                _pdfAmountFmt.format(totalDep),
              ],
              [
                "Total Client Redemptions Processed",
                "(${_pdfAmountFmt.format(totalWdr.abs())})",
              ],
              [
                "Total Net Realized Profits Credited",
                _pdfAmountFmt.format(totalPr > 0 ? totalPr : 0),
              ],
              [
                "Total Portfolio Loss Adjustments",
                totalPr < 0
                    ? "(${_pdfAmountFmt.format(totalPr.abs())})"
                    : _pdfAmountFmt.format(0.0),
              ],
              [
                "Total Management Fees Charged",
                "(${_pdfAmountFmt.format(totalMgmtFee)})",
              ],
              [
                "Total Other Fees & Charges",
                "(${_pdfAmountFmt.format(totalOtherFees)})",
              ],
              [
                "Closing Portfolio Value",
                _pdfAmountFmt.format(
                  totalDep -
                      totalWdr.abs() +
                      totalPr -
                      totalMgmtFee -
                      totalOtherFees,
                ),
              ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: _brandGreen),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FixedColumnWidth(130),
            },
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
            },
            border: pw.TableBorder.all(
              color: PdfColors.grey300,
              width: 0.5,
            ),
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            "Fee Disclosure",
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: [
              "Fee Type",
              "Rate",
              "Amount Charged (PKR)",
            ],
            data: [
              [
                "Front-End Processing Fee",
                "2.00%",
                _pdfAmountFmt.format(totalFrontEndFee),
              ],
              [
                "Portfolio Management Fee",
                "1.50% per annum",
                _pdfAmountFmt.format(totalMgmtFee),
              ],
              [
                "Performance Participation Fee",
                "15% of net profits",
                _pdfAmountFmt.format(totalPerfFee),
              ],
              [
                "Referral Commission",
                "Up to 1%",
                _pdfAmountFmt.format(totalReferralFee),
              ],
              [
                "Total Fees & Charges",
                "",
                _pdfAmountFmt.format(
                  totalFrontEndFee +
                      totalMgmtFee +
                      totalPerfFee +
                      totalReferralFee,
                ),
              ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: _brandGreen),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FixedColumnWidth(120),
              2: const pw.FixedColumnWidth(130),
            },
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
            },
            border: pw.TableBorder.all(
              color: PdfColors.grey300,
              width: 0.5,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            "Note: All fees are deducted in accordance with the "
            "Investor Participation Agreement signed by the investor. "
            "Performance fees are charged only on net positive returns. "
            "Front-end processing fee is deducted at time of deposit.",
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            "Investment Result",
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ["Particulars", "Amount (PKR)"],
            data: [
              [
                "Gross Investment Return",
                _pdfAmountFmt.format(totalPr > 0 ? totalPr : 0),
              ],
              [
                "Total Loss Adjustments",
                totalPr < 0
                    ? "(${_pdfAmountFmt.format(totalPr.abs())})"
                    : _pdfAmountFmt.format(0.0),
              ],
              [
                "Net Investment Return",
                _pdfAmountFmt.format(totalPr),
              ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: _brandGreen),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FixedColumnWidth(130),
            },
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
            },
            border: pw.TableBorder.all(
              color: PdfColors.grey300,
              width: 0.5,
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            "Notes",
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          _buildNote(
            "1.",
            "Profit allocations are credited after realization "
            "and settlement at 00:05 PKT on the following trading day.",
          ),
          _buildNote(
            "2.",
            "Loss adjustments represent realized portfolio losses "
            "on trading days where market performance was negative.",
          ),
          _buildNote(
            "3.",
            "Performance fees are charged only on net positive "
            "returns in accordance with the High-Water Mark principle.",
          ),
          _buildNote(
            "4.",
            "Withdrawals and redemptions are processed subject to "
            "portfolio liquidity and the applicable notice period "
            "as per the Investor Participation Agreement.",
          ),
          _buildNote(
            "5.",
            "Management fees accrue daily and are reflected in "
            "the portfolio valuation.",
          ),
          _buildNote(
            "6.",
            "All amounts are stated in Pakistani Rupees (PKR).",
          ),
          _buildNote(
            "7.",
            "This statement is generated from your account activity "
            "on the Amanah Multi Asset Portfolio platform. For "
            "queries, contact: contact@islamicsavingcenter.com",
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 150,
                    height: 1,
                    color: _brandGreen,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    "Authorized Signatory",
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    "Portfolio Management Division",
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    "AMANAH MULTI ASSET PORTFOLIO",
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  "Portfolio Management Division",
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _brandGreen,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  "This report is system generated and does not require any signature.",
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  return pdf.save();
}
