import "dart:typed_data";

import "package:flutter/foundation.dart" show debugPrint;
import "package:flutter/services.dart" show rootBundle;
import "package:intl/intl.dart";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;

import "package:portfolio_app/src/core/branding/brand_assets.dart";
import "package:portfolio_app/src/features/investment/data/models/sleeve_purchase_entry.dart";
import "package:portfolio_app/src/features/investment/domain/market_sleeve_balance.dart";

// ─── Constants ────────────────────────────────────────────────────────────────

final _brandGreen = PdfColor.fromHex("#0F7A2C");
const _white = PdfColors.white;
const _black = PdfColors.black;
final _footerLabelGrey = PdfColor.fromInt(0xFF555555);
final _positiveGreen = PdfColor.fromHex("#1D9C49");
final _negativeRed = PdfColor.fromHex("#D14343");

const _accentLineWidth = 4.0;
const _pageMarginLeft = 40.0;

// ─── Formatters ────────────────────────────────────────────────────────────────

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);
final _tolaPriceFmt = NumberFormat.decimalPatternDigits(decimalDigits: 2);
final _tolaFmt = NumberFormat.decimalPatternDigits(decimalDigits: 4);
final _dateFmt = DateFormat("dd MMM yyyy");

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _generateRefNumber(String portfolioNumber) {
  if (portfolioNumber.isEmpty) return "AMAPISCPK-000000000";
  return portfolioNumber;
}

String _formatLetterheadDate(DateTime date) {
  return "${date.day.toString().padLeft(2, "0")}/"
      "${date.month.toString().padLeft(2, "0")}/"
      "${date.year}";
}

// ─── Letterhead ────────────────────────────────────────────────────────────────

pw.Widget _buildSleeveLetterheadHeader(
  pw.MemoryImage? logo, {
  required String title,
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
                title,
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
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

pw.Widget _sleeveFooterRow(String label, String value) {
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
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 7.5, color: _black),
        ),
      ],
    ),
  );
}

pw.Widget _buildSleeveLetterheadFooter() {
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
                _sleeveFooterRow("Contact Number", "021-34010616"),
                _sleeveFooterRow("Contact on", "contact@islamicsavingcenter.com"),
                _sleeveFooterRow("For Information", "contact@islamicsavingcenter.com"),
                _sleeveFooterRow("Visit our website", "www.islamicsavingcenter.com"),
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

pw.Widget _buildSleevePageBackground(pw.MemoryImage? logo) {
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

// ─── Meta table ────────────────────────────────────────────────────────────────

pw.Widget _buildSleeveMetaTable({
  required String accountTitle,
  required String portfolioNumber,
  required String period,
  required Map<String, String> colLabels,
}) {
  final labelStyle = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
  final valueStyle = pw.TextStyle(fontSize: 9);

  pw.Widget headerCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(text, style: labelStyle),
        ),
      );

  pw.Widget valueCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(text, style: valueStyle),
        ),
      );

  final accountLabel = colLabels["meta_account"] ?? "Account";
  final portfolioLabel = colLabels["meta_portfolio"] ?? "Portfolio No.";
  final periodLabel = colLabels["meta_period"] ?? "Period";

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    columnWidths: {
      0: const pw.FlexColumnWidth(2),
      1: const pw.FlexColumnWidth(3),
    },
    children: [
      pw.TableRow(children: [headerCell(accountLabel), valueCell(accountTitle)]),
      pw.TableRow(
          children: [headerCell(portfolioLabel), valueCell(portfolioNumber)]),
      pw.TableRow(children: [headerCell(periodLabel), valueCell(period)]),
    ],
  );
}

// ─── Date filtering ────────────────────────────────────────────────────────────

List<SleevePurchaseEntry> _filterEntries(
  List<SleevePurchaseEntry> entries,
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
  final filtered = entries
      .where(
        (e) =>
            !e.depositDate.isBefore(a) && !e.depositDate.isAfter(b),
      )
      .toList();
  // Re-number sno.
  return [
    for (var i = 0; i < filtered.length; i++)
      SleevePurchaseEntry(
        sno: i + 1,
        depositDate: filtered[i].depositDate,
        depositTotal: filtered[i].depositTotal,
        investedPkr: filtered[i].investedPkr,
        purchasePricePerTola: filtered[i].purchasePricePerTola,
        tolasBought: filtered[i].tolasBought,
        currentPricePerTola: filtered[i].currentPricePerTola,
        precomputedPnl: filtered[i].precomputedPnl,
        note: filtered[i].note,
      ),
  ];
}

// ─── Unified 7-column table ────────────────────────────────────────────────────

pw.Widget _buildSleeveTable(
  List<SleevePurchaseEntry> rows,
  Map<String, String> colLabels, {
  bool isRate = false,
  required String dcaLabel,
  required String dcaNaLabel,
}) {
  final headerStyle = pw.TextStyle(
    fontSize: 8,
    fontWeight: pw.FontWeight.bold,
    color: _white,
  );
  final cellStyle = pw.TextStyle(fontSize: 8);
  final boldStyle = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);

  String fmtPrice(double? v) {
    if (v == null) return "—";
    return isRate ? "${v.toStringAsFixed(1)}%" : _tolaPriceFmt.format(v);
  }

  String fmtUnits(double? v) {
    if (v == null) return "—";
    return _tolaFmt.format(v);
  }

  final snoLabel = colLabels["sno"] ?? "S.No";
  final dateLabel = colLabels["date"] ?? "Date";
  final priceAtPurchaseLabel = colLabels["price_at_purchase"] ?? "Price";
  final unitsLabel = colLabels["units"] ?? "Units";
  final investedLabel = colLabels["invested"] ?? "PKR Invested";
  final currentPriceLabel = colLabels["current_price"] ?? "Current";
  final plLabel = colLabels["pl"] ?? "P/L";

  final columnWidths = <int, pw.TableColumnWidth>{
    0: const pw.FixedColumnWidth(28),
    1: const pw.FlexColumnWidth(2),
    2: const pw.FlexColumnWidth(2.5),
    3: const pw.FlexColumnWidth(2),
    4: const pw.FlexColumnWidth(2.5),
    5: const pw.FlexColumnWidth(2.5),
    6: const pw.FlexColumnWidth(2.5),
  };

  pw.Widget hCell(String text) => pw.Container(
        color: _brandGreen,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: pw.Text(text, style: headerStyle, textAlign: pw.TextAlign.center),
      );

  pw.Widget cell(
    String text, {
    pw.TextAlign align = pw.TextAlign.center,
    pw.TextStyle? style,
    PdfColor? color,
  }) {
    final s = (style ?? cellStyle).copyWith(color: color ?? _black);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(text, style: s, textAlign: align),
    );
  }

  // Header row
  final headerRow = pw.TableRow(
    children: [
      hCell(snoLabel),
      hCell(dateLabel),
      hCell(priceAtPurchaseLabel),
      hCell(unitsLabel),
      hCell(investedLabel),
      hCell(currentPriceLabel),
      hCell(plLabel),
    ],
  );

  // Data rows
  final dataRows = <pw.TableRow>[];
  for (var i = 0; i < rows.length; i++) {
    final e = rows[i];
    final bg = i.isEven ? PdfColors.white : PdfColors.grey100;
    final pnl = e.netProfitPkr;
    PdfColor? plColor;
    if (pnl != null) {
      plColor = pnl >= 0 ? _positiveGreen : _negativeRed;
    }

    dataRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: bg),
        children: [
          cell("${e.sno}"),
          cell(_dateFmt.format(e.depositDate), align: pw.TextAlign.left),
          cell(fmtPrice(e.purchasePricePerTola)),
          cell(fmtUnits(e.tolasBought)),
          cell(_money.format(e.investedPkr), align: pw.TextAlign.right),
          cell(fmtPrice(e.currentPricePerTola)),
          cell(
            pnl != null ? _money.format(pnl) : "—",
            align: pw.TextAlign.right,
            color: plColor,
          ),
        ],
      ),
    );
  }

  // Summary row
  final totalInvested = rows.fold<double>(0, (s, e) => s + e.investedPkr);
  final totalUnits = rows.every((e) => e.tolasBought != null)
      ? rows.fold<double>(0, (s, e) => s + (e.tolasBought ?? 0))
      : null;
  final totalPnl = rows.every((e) => e.netProfitPkr != null)
      ? rows.fold<double>(0, (s, e) => s + (e.netProfitPkr ?? 0))
      : null;
  final totalLabel = colLabels["total"] ?? "Total";
  final totalPnlColor = totalPnl == null
      ? null
      : totalPnl >= 0
          ? _positiveGreen
          : _negativeRed;

  dataRows.add(
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        cell(""),
        cell(totalLabel, style: boldStyle, align: pw.TextAlign.left),
        cell(""),
        cell(totalUnits != null ? _tolaFmt.format(totalUnits) : "—",
            style: boldStyle),
        cell(_money.format(totalInvested),
            align: pw.TextAlign.right, style: boldStyle),
        cell(""),
        cell(
          totalPnl != null ? _money.format(totalPnl) : "—",
          align: pw.TextAlign.right,
          style: boldStyle,
          color: totalPnlColor,
        ),
      ],
    ),
  );

  // ── DCA calculation ──────────────────────────────────────────────────────
  // Only rows that have a resolved purchase price contribute to DCA.
  final rowsWithUnits = rows.where((e) => e.tolasBought != null).toList();
  final totalInvestedForDca =
      rowsWithUnits.fold<double>(0, (s, e) => s + e.investedPkr);
  final totalUnitsForDca =
      rowsWithUnits.fold<double>(0, (s, e) => s + (e.tolasBought ?? 0));
  final dca =
      totalUnitsForDca > 0 ? totalInvestedForDca / totalUnitsForDca : null;

  // Unit label — strip embedded newlines used in column headers.
  final unitLabelClean = (colLabels["units"] ?? "Units").replaceAll("\n", " ");

  final dcaValueText = isRate
      ? null
      : dca != null
          ? "${_money.format(dca)} / $unitLabelClean"
          : "—";

  final dcaRow = pw.Container(
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
    ),
    padding: const pw.EdgeInsets.only(top: 6, bottom: 4),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            isRate ? dcaNaLabel : dcaLabel,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: isRate ? PdfColors.grey600 : _brandGreen,
              fontStyle:
                  isRate ? pw.FontStyle.italic : pw.FontStyle.normal,
            ),
          ),
        ),
        if (!isRate)
          pw.Text(
            dcaValueText ?? "—",
            style: pw.TextStyle(fontSize: 9, color: _black),
            textAlign: pw.TextAlign.right,
          ),
      ],
    ),
  );

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.3),
        columnWidths: columnWidths,
        children: [headerRow, ...dataRows],
      ),
      dcaRow,
    ],
  );
}

// ─── Footnotes ─────────────────────────────────────────────────────────────────

pw.Widget _buildFootnotes(
  List<SleevePurchaseEntry> entries,
  Map<String, String> colLabels, {
  required bool isRate,
  required double? currentGoldPricePerTola,
}) {
  final notes = <String>[];
  final hasMissing = entries.any((e) => e.purchasePricePerTola == null);

  if (isRate) {
    final rateNote = colLabels["non_gold_note"] ?? "";
    if (rateNote.isNotEmpty) notes.add(rateNote);
  } else {
    if (hasMissing) {
      final note = colLabels["missing_px_note"] ?? "";
      if (note.isNotEmpty) notes.add(note);
    }
    if (currentGoldPricePerTola != null) {
      final note = colLabels["current_px_note"] ?? "";
      if (note.isNotEmpty) {
        notes.add("$note ${_money.format(currentGoldPricePerTola)}");
      }
    }
  }

  if (notes.isEmpty) return pw.SizedBox.shrink();

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(height: 8),
      for (final n in notes)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(
            n,
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
          ),
        ),
    ],
  );
}

// ─── Public: single-sleeve PDF ─────────────────────────────────────────────────

/// Builds a single-sleeve PDF. Returns bytes for [Printing.layoutPdf].
Future<Uint8List> buildSleeveReportPdf({
  required MarketSleeve sleeve,
  required List<SleevePurchaseEntry> entries,
  required DateTime periodStart,
  required DateTime periodEndInclusive,
  required String accountTitle,
  required String portfolioNumber,
  required String pdfTitle,
  double? currentGoldPricePerTola,
  required Map<String, String> colLabels,
  required String dcaLabel,
  required String dcaNaLabel,
}) async {
  pw.MemoryImage? logoImage;
  try {
    final logoBytes = (await rootBundle.load(BrandAssets.logoGreenPng))
        .buffer
        .asUint8List();
    logoImage = pw.MemoryImage(logoBytes);
  } catch (e) {
    debugPrint("[sleeve_report] Logo load failed: $e");
  }

  final filtered =
      _filterEntries(entries, periodStart, periodEndInclusive);
  final refNumber = _generateRefNumber(portfolioNumber);
  final letterheadDate = _formatLetterheadDate(DateTime.now());
  final periodStr =
      "${_dateFmt.format(periodStart)} – ${_dateFmt.format(periodEndInclusive)}";

  final isRate = sleeve == MarketSleeve.tech ||
      sleeve == MarketSleeve.debt ||
      sleeve == MarketSleeve.money;

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(
          left: _pageMarginLeft,
          right: 30,
          top: 16,
          bottom: 16,
        ),
        buildBackground: (_) => _buildSleevePageBackground(logoImage),
      ),
      header: (_) => pw.Column(
        children: [
          _buildSleeveLetterheadHeader(logoImage, title: pdfTitle),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Ref #: $refNumber",
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.Text("Date: $letterheadDate",
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
        ],
      ),
      footer: (_) => _buildSleeveLetterheadFooter(),
      build: (ctx) => [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              pdfTitle,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
              ),
            ),
            pw.SizedBox(height: 10),
            _buildSleeveMetaTable(
              accountTitle: accountTitle,
              portfolioNumber: portfolioNumber,
              period: periodStr,
              colLabels: colLabels,
            ),
            pw.SizedBox(height: 12),
            if (filtered.isEmpty)
              pw.Text(
                colLabels["no_data"] ?? "No deposits found.",
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              )
            else ...[
              _buildSleeveTable(
                filtered,
                colLabels,
                isRate: isRate,
                dcaLabel: dcaLabel,
                dcaNaLabel: dcaNaLabel,
              ),
              _buildFootnotes(
                filtered,
                colLabels,
                isRate: isRate,
                currentGoldPricePerTola: currentGoldPricePerTola,
              ),
            ],
          ],
        ),
      ],
    ),
  );

  return pdf.save();
}

// ─── Public: combined 5-sleeve PDF ────────────────────────────────────────────

/// Builds one PDF with 5 sections (one per sleeve) separated by page breaks.
Future<Uint8List> buildCombinedSleeveReportPdf({
  required Map<MarketSleeve, List<SleevePurchaseEntry>> entriesBySleeve,
  required DateTime periodStart,
  required DateTime periodEndInclusive,
  required String accountTitle,
  required String portfolioNumber,
  required String pdfTitle,
  double? currentGoldPricePerTola,
  required Map<String, String> colLabels,
  required String dcaLabel,
  required String dcaNaLabel,
}) async {
  pw.MemoryImage? logoImage;
  try {
    final logoBytes = (await rootBundle.load(BrandAssets.logoGreenPng))
        .buffer
        .asUint8List();
    logoImage = pw.MemoryImage(logoBytes);
  } catch (e) {
    debugPrint("[sleeve_report] Logo load failed: $e");
  }

  final refNumber = _generateRefNumber(portfolioNumber);
  final letterheadDate = _formatLetterheadDate(DateTime.now());
  final periodStr =
      "${_dateFmt.format(periodStart)} – ${_dateFmt.format(periodEndInclusive)}";

  final sleeveOrder = [
    MarketSleeve.gold,
    MarketSleeve.stock,
    MarketSleeve.tech,
    MarketSleeve.debt,
    MarketSleeve.money,
  ];

  final sectionTitleKeys = {
    MarketSleeve.gold: "section_gold",
    MarketSleeve.stock: "section_stock",
    MarketSleeve.tech: "section_tech",
    MarketSleeve.debt: "section_debt",
    MarketSleeve.money: "section_money",
  };

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(
          left: _pageMarginLeft,
          right: 30,
          top: 16,
          bottom: 16,
        ),
        buildBackground: (_) => _buildSleevePageBackground(logoImage),
      ),
      header: (_) => pw.Column(
        children: [
          _buildSleeveLetterheadHeader(logoImage, title: pdfTitle),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Ref #: $refNumber",
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.Text("Date: $letterheadDate",
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
        ],
      ),
      footer: (_) => _buildSleeveLetterheadFooter(),
      build: (ctx) {
        final widgets = <pw.Widget>[];

        // Cover meta
        widgets.add(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                pdfTitle,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildSleeveMetaTable(
                accountTitle: accountTitle,
                portfolioNumber: portfolioNumber,
                period: periodStr,
                colLabels: colLabels,
              ),
            ],
          ),
        );

        for (final sleeve in sleeveOrder) {
          widgets.add(pw.NewPage());

          final isRate = sleeve == MarketSleeve.tech ||
              sleeve == MarketSleeve.debt ||
              sleeve == MarketSleeve.money;
          final entries =
              _filterEntries(entriesBySleeve[sleeve] ?? [], periodStart, periodEndInclusive);
          final sectionTitleKey = sectionTitleKeys[sleeve] ?? "";
          final sectionTitle = colLabels[sectionTitleKey] ?? sleeve.name;

          widgets.add(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  sectionTitle,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _brandGreen,
                  ),
                ),
                pw.SizedBox(height: 8),
                if (entries.isEmpty)
                  pw.Text(
                    colLabels["no_data"] ?? "No deposits found.",
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  )
                else ...[
                  _buildSleeveTable(
                    entries,
                    colLabels,
                    isRate: isRate,
                    dcaLabel: dcaLabel,
                    dcaNaLabel: dcaNaLabel,
                  ),
                  _buildFootnotes(
                    entries,
                    colLabels,
                    isRate: isRate,
                    currentGoldPricePerTola:
                        sleeve == MarketSleeve.gold ? currentGoldPricePerTola : null,
                  ),
                ],
              ],
            ),
          );
        }

        return widgets;
      },
    ),
  );

  return pdf.save();
}
