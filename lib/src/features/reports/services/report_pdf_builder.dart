import "dart:typed_data";

import "package:intl/intl.dart";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;

import "../../investor/data/models/txn_item.dart";

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
    required this.colDate,
    required this.colType,
    required this.colStatus,
    required this.colAmount,
    required this.colNote,
    required this.totalDeposits,
    required this.totalWithdrawals,
    required this.totalProfit,
    required this.footer,
    required this.transactionsHeading,
  });

  final String documentTitle;
  final String headerAccountTitle;
  final String headerPortfolioNo;
  final String headerReportType;
  final String reportTypeFiveMarket;
  final String reportTypeMonthly;
  final String period;
  final String summary;
  final String colDate;
  final String colType;
  final String colStatus;
  final String colAmount;
  final String colNote;
  final String totalDeposits;
  final String totalWithdrawals;
  final String totalProfit;
  final String footer;
  final String transactionsHeading;
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

  pw.Widget headerCell(String text, {pw.Alignment align = pw.Alignment.centerLeft}) {
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

/// Builds a multi-page A4 PDF; returns bytes for [Printing.layoutPdf].
Future<Uint8List> buildInvestorReportPdf({
  required String accountLabel,
  required String portfolioNumber,
  required ReportType reportType,
  required DateTime periodStart,
  required DateTime periodEndInclusive,
  required List<TxnItem> transactions,
  required ReportPdfLabels labels,
}) async {
  final dateFmt = DateFormat.yMMMd();
  final dateTimeFmt = DateFormat.yMMMd().add_Hm();

  double totalDep = 0;
  double totalWdr = 0;
  double totalPr = 0;
  for (final t in transactions) {
    final st = t.status;
    final ty = t.type;
    if (ty == "deposit" && st == "approved") {
      totalDep += t.amount;
    } else if (ty == "withdrawal" &&
        (st == "approved" || st == "completed")) {
      totalWdr += t.amount;
    } else if ((ty == "profit" || ty == "profit_entry") &&
        (st == "approved" || st == "completed")) {
      totalPr += t.amount;
    }
  }

  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => [
        pw.Header(
          level: 0,
          child: pw.Text(
            labels.documentTitle,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
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
          "${labels.period}: ${dateFmt.format(periodStart)} – ${dateFmt.format(periodEndInclusive)}",
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          labels.summary,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.Bullet(text: "${labels.totalDeposits}: ${totalDep.toStringAsFixed(2)}"),
        pw.Bullet(text: "${labels.totalWithdrawals}: ${totalWdr.toStringAsFixed(2)}"),
        pw.Bullet(text: "${labels.totalProfit}: ${totalPr.toStringAsFixed(2)}"),
        pw.SizedBox(height: 16),
        pw.Text(
          labels.transactionsHeading,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        if (transactions.isEmpty)
          pw.Text("—")
        else
          pw.TableHelper.fromTextArray(
            headers: [
              labels.colDate,
              labels.colType,
              labels.colStatus,
              labels.colAmount,
              labels.colNote,
            ],
            data: transactions.map((t) {
              final note = (t.note ?? "").replaceAll("\n", " ");
              final shortNote =
                  note.length > 40 ? "${note.substring(0, 37)}..." : note;
              return [
                dateTimeFmt.format(t.createdAt),
                t.type,
                t.status,
                t.amount.toStringAsFixed(2),
                shortNote,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey300,
            ),
            cellHeight: 24,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerLeft,
            },
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
