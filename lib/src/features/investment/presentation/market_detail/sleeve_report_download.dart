import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:printing/printing.dart";

import "package:portfolio_app/src/core/i18n/app_translations.dart";
import "package:portfolio_app/src/features/investment/domain/market_sleeve_balance.dart";
import "package:portfolio_app/src/features/investment/presentation/market_detail/market_detail_providers.dart";
import "package:portfolio_app/src/features/investment/presentation/widgets/report_date_filter_sheet.dart";
import "package:portfolio_app/src/features/investment/providers/sleeve_purchase_report_provider.dart";
import "package:portfolio_app/src/features/investment/services/sleeve_report_pdf_builder.dart";
import "package:portfolio_app/src/providers/auth_providers.dart";

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Last 8 chars of UID, uppercased. Same logic as reports_screen.
String portfolioNumberFromUid(String uid) {
  final t = uid.trim();
  return t.length >= 8 ? t.substring(t.length - 8).toUpperCase() : t.toUpperCase();
}

/// Builds the full colLabels map from localised strings, sleeve-specific.
Map<String, String> sleeveReportColLabels(
  BuildContext ctx,
  MarketSleeve sleeve,
) {
  final isRate = sleeve == MarketSleeve.tech ||
      sleeve == MarketSleeve.debt ||
      sleeve == MarketSleeve.money;

  return {
    "sno": ctx.tr("sleeve_report_col_sno"),
    "date": ctx.tr("sleeve_report_col_date"),
    "price_at_purchase": isRate
        ? ctx.tr("sleeve_report_col_rate_at_purchase")
        : sleeve == MarketSleeve.gold
            ? ctx.tr("sleeve_report_col_purchase_px")
            : ctx.tr("sleeve_report_col_index_at_purchase"),
    "units": isRate
        ? ctx.tr("sleeve_report_col_rate_na")
        : sleeve == MarketSleeve.gold
            ? ctx.tr("sleeve_report_col_tolas_label")
            : ctx.tr("sleeve_report_col_index_units"),
    "invested": ctx.tr("sleeve_report_col_invested"),
    "current_price": isRate
        ? ctx.tr("sleeve_report_col_current_rate")
        : sleeve == MarketSleeve.gold
            ? ctx.tr("sleeve_report_col_current_px")
            : ctx.tr("sleeve_report_col_current_index"),
    "pl": isRate
        ? ctx.tr("sleeve_report_col_accrued_pl")
        : ctx.tr("sleeve_report_col_pl"),
    "total": ctx.tr("sleeve_report_total"),
    "no_data": ctx.tr("sleeve_report_no_data"),
    "missing_px_note": ctx.tr("sleeve_report_missing_px_note"),
    "current_px_note": ctx.tr("sleeve_report_current_px_note"),
    "non_gold_note": ctx.tr("sleeve_report_rate_pl_note"),
    "meta_account": ctx.tr("sleeve_report_meta_account"),
    "meta_portfolio": ctx.tr("sleeve_report_meta_portfolio"),
    "meta_period": ctx.tr("sleeve_report_meta_period"),
    "section_gold": ctx.tr("sleeve_report_section_gold"),
    "section_stock": ctx.tr("sleeve_report_section_stock"),
    "section_tech": ctx.tr("sleeve_report_section_tech"),
    "section_debt": ctx.tr("sleeve_report_section_debt"),
    "section_money": ctx.tr("sleeve_report_section_money"),
    "dca_label": ctx.tr("sleeve_report_dca_label"),
    "dca_na": ctx.tr("sleeve_report_dca_na"),
  };
}

// ─── Single-sleeve download ────────────────────────────────────────────────────

/// Shows the date filter sheet; on confirm, builds and opens the PDF.
Future<void> openSleeveReportDownload({
  required BuildContext context,
  required WidgetRef ref,
  required MarketSleeve sleeve,
  required String reportTitle,
  required String pdfTitle,
}) async {
  // Capture context-dependent values before any await.
  final colLabels = sleeveReportColLabels(context, sleeve);
  final messenger = ScaffoldMessenger.of(context);
  final generatingMsg = context.tr("sleeve_report_generating");
  final errorMsg = context.tr("sleeve_report_error");

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ReportDateFilterSheet(
      reportTitle: reportTitle,
      onDownload: (start, end) async {
        messenger.showSnackBar(SnackBar(content: Text(generatingMsg)));

        try {
          ref.invalidate(sleevePurchaseEntriesProvider(sleeve));
          final entries =
              await ref.read(sleevePurchaseEntriesProvider(sleeve).future);

          final prof = ref.read(userProfileProvider).valueOrNull;
          final auth = ref.read(currentUserProvider);
          final accountTitle =
              (prof != null && prof.name.trim().isNotEmpty)
                  ? prof.name.trim()
                  : (auth?.email ?? "");
          final uid = auth?.uid ?? "";
          final portfolioNumber =
              uid.isNotEmpty ? portfolioNumberFromUid(uid) : "";

          final currentGoldPrice = sleeve == MarketSleeve.gold
              ? ref.read(goldPricePerTolaProvider)
              : null;

          final bytes = await buildSleeveReportPdf(
            sleeve: sleeve,
            entries: entries,
            periodStart: start,
            periodEndInclusive: end,
            accountTitle: accountTitle,
            portfolioNumber: portfolioNumber,
            pdfTitle: pdfTitle,
            currentGoldPricePerTola: currentGoldPrice,
            colLabels: colLabels,
            dcaLabel: colLabels["dca_label"] ?? "Avg Cost (DCA)",
            dcaNaLabel: colLabels["dca_na"] ?? "N/A — fixed rate sleeve",
          );

          await Printing.layoutPdf(onLayout: (_) async => bytes);
        } catch (e, st) {
          debugPrint("[sleeve_report] download failed: $e\n$st");
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(errorMsg)));
          rethrow;
        }
      },
    ),
  );
}

// ─── Combined 5-sleeve download ────────────────────────────────────────────────

/// Shows the date filter sheet; on confirm, builds a combined 5-section PDF.
Future<void> openCombinedSleeveReportDownload({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  // Capture context-dependent values before any await.
  final combinedColLabels = sleeveReportColLabels(context, MarketSleeve.gold);
  final messenger = ScaffoldMessenger.of(context);
  final generatingMsg = context.tr("sleeve_report_generating");
  final errorMsg = context.tr("sleeve_report_error");
  final pdfTitle = context.tr("sleeve_report_pdf_title_all");

  // Invalidate all sleeves.
  for (final s in MarketSleeve.values) {
    ref.invalidate(sleevePurchaseEntriesProvider(s));
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ReportDateFilterSheet(
      reportTitle: pdfTitle,
      onDownload: (start, end) async {
        messenger.showSnackBar(SnackBar(content: Text(generatingMsg)));

        try {
          final results = await Future.wait([
            ref.read(sleevePurchaseEntriesProvider(MarketSleeve.gold).future),
            ref.read(sleevePurchaseEntriesProvider(MarketSleeve.stock).future),
            ref.read(sleevePurchaseEntriesProvider(MarketSleeve.tech).future),
            ref.read(sleevePurchaseEntriesProvider(MarketSleeve.debt).future),
            ref.read(sleevePurchaseEntriesProvider(MarketSleeve.money).future),
          ]);

          final prof = ref.read(userProfileProvider).valueOrNull;
          final auth = ref.read(currentUserProvider);
          final accountTitle =
              (prof != null && prof.name.trim().isNotEmpty)
                  ? prof.name.trim()
                  : (auth?.email ?? "");
          final uid = auth?.uid ?? "";
          final portfolioNumber =
              uid.isNotEmpty ? portfolioNumberFromUid(uid) : "";

          final currentGoldPrice = ref.read(goldPricePerTolaProvider);

          final bytes = await buildCombinedSleeveReportPdf(
            entriesBySleeve: {
              MarketSleeve.gold: results[0],
              MarketSleeve.stock: results[1],
              MarketSleeve.tech: results[2],
              MarketSleeve.debt: results[3],
              MarketSleeve.money: results[4],
            },
            periodStart: start,
            periodEndInclusive: end,
            accountTitle: accountTitle,
            portfolioNumber: portfolioNumber,
            pdfTitle: pdfTitle,
            currentGoldPricePerTola: currentGoldPrice,
            colLabels: combinedColLabels,
            dcaLabel: combinedColLabels["dca_label"] ?? "Avg Cost (DCA)",
            dcaNaLabel:
                combinedColLabels["dca_na"] ?? "N/A — fixed rate sleeve",
          );

          await Printing.layoutPdf(onLayout: (_) async => bytes);
        } catch (e, st) {
          debugPrint("[sleeve_report] combined download failed: $e\n$st");
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(errorMsg)));
          rethrow;
        }
      },
    ),
  );
}
