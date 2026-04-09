import "dart:typed_data";

import "package:file_saver/file_saver.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";
import "package:printing/printing.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../providers/auth_providers.dart";
import "../../../providers/reports_providers.dart";
import "../../../providers/transaction_history_providers.dart";
import "../services/report_pdf_builder.dart";
import "report_pdf_preview_screen.dart";

enum _PeriodPreset { thisMonth, thisYear, custom }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _PeriodPreset _preset = _PeriodPreset.thisMonth;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _customStart = DateTime(n.year, n.month, 1);
    _customEnd = n;
  }

  DateTimeRange _resolvedRange() {
    final now = DateTime.now();
    switch (_preset) {
      case _PeriodPreset.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999),
        );
      case _PeriodPreset.thisYear:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, 12, 31, 23, 59, 59, 999),
        );
      case _PeriodPreset.custom:
        final s = _customStart ?? DateTime(now.year, now.month, 1);
        final e = _customEnd ?? now;
        return DateTimeRange(
          start: DateTime(s.year, s.month, s.day),
          end: DateTime(e.year, e.month, e.day, 23, 59, 59, 999),
        );
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial =
        isStart ? (_customStart ?? DateTime.now()) : (_customEnd ?? DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (d == null || !mounted) return;
    setState(() {
      if (isStart) {
        _customStart = d;
      } else {
        _customEnd = d;
      }
      _preset = _PeriodPreset.custom;
    });
  }

  ReportPdfLabels _labels(BuildContext context) {
    return ReportPdfLabels(
      documentTitle: context.tr("reports_pdf_doc_title"),
      account: context.tr("reports_account"),
      period: context.tr("reports_period"),
      summary: context.tr("reports_summary"),
      colDate: context.tr("reports_col_date"),
      colType: context.tr("reports_col_type"),
      colStatus: context.tr("reports_col_status"),
      colAmount: context.tr("reports_col_amount"),
      colNote: context.tr("reports_col_note"),
      totalDeposits: context.tr("reports_total_deposits"),
      totalWithdrawals: context.tr("reports_total_withdrawals"),
      totalProfit: context.tr("reports_total_profit"),
      footer: context.tr("reports_pdf_footer"),
      transactionsHeading: context.tr("reports_pdf_transactions_heading"),
    );
  }

  Future<Uint8List?> _buildPdfBytes() async {
    final range = _resolvedRange();
    if (range.start.isAfter(range.end)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr("reports_invalid_range"))),
        );
      }
      return null;
    }

    final txs = ref.read(userTransactionItemsProvider).valueOrNull ?? [];
    final filtered = filterTxnsInRange(txs, range.start, range.end);

    final prof = ref.read(userProfileProvider).valueOrNull;
    final auth = ref.read(currentUserProvider);
    final accountLabel = (prof != null && prof.name.trim().isNotEmpty)
        ? prof.name.trim()
        : (auth?.email ?? "");

    final ps = DateTime(range.start.year, range.start.month, range.start.day);
    final pe = DateTime(range.end.year, range.end.month, range.end.day);

    try {
      return await buildInvestorReportPdf(
        accountLabel: accountLabel,
        periodStart: ps,
        periodEndInclusive: pe,
        transactions: filtered,
        labels: _labels(context),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr("reports_pdf_failed"))),
        );
      }
      return null;
    }
  }

  String _pdfFileName() {
    final range = _resolvedRange();
    final ps = DateTime(range.start.year, range.start.month, range.start.day);
    final pe = DateTime(range.end.year, range.end.month, range.end.day);
    return "wakalat-report-${DateFormat("yyyy-MM-dd").format(ps)}-${DateFormat("yyyy-MM-dd").format(pe)}.pdf";
  }

  Future<void> _viewReport() async {
    final bytes = await _buildPdfBytes();
    if (bytes == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => ReportPdfPreviewScreen(
          bytes: bytes,
          fileName: _pdfFileName(),
        ),
      ),
    );
  }

  Future<void> _downloadReport() async {
    final bytes = await _buildPdfBytes();
    if (bytes == null || !mounted) return;
    final fileName = _pdfFileName();
    try {
      final base = fileName.replaceAll(".pdf", "");
      await FileSaver.instance.saveFile(
        name: base,
        bytes: bytes,
        fileExtension: "pdf",
        mimeType: MimeType.pdf,
      );
    } catch (_) {
      // Fallback for devices where direct file saver integration is restricted.
      try {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
        return;
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr("reports_pdf_failed"))),
        );
      }
    }
  }

  Future<void> _printReport() async {
    final bytes = await _buildPdfBytes();
    if (bytes == null || !mounted) return;
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: _pdfFileName(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = _resolvedRange();
    final txsAsync = ref.watch(userTransactionItemsProvider);
    final teamAsync = ref.watch(userReportsProvider);

    final filtered = txsAsync.maybeWhen(
      data: (list) => filterTxnsInRange(list, range.start, range.end),
      orElse: () => <TxnItem>[],
    );

    return AppScaffold(
      title: context.tr("reports_center_title"),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.tr("reports_select_period"),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(context.tr("reports_period_this_month")),
                selected: _preset == _PeriodPreset.thisMonth,
                onSelected: (v) {
                  if (v) setState(() => _preset = _PeriodPreset.thisMonth);
                },
              ),
              ChoiceChip(
                label: Text(context.tr("reports_period_this_year")),
                selected: _preset == _PeriodPreset.thisYear,
                onSelected: (v) {
                  if (v) setState(() => _preset = _PeriodPreset.thisYear);
                },
              ),
              ChoiceChip(
                label: Text(context.tr("reports_period_custom")),
                selected: _preset == _PeriodPreset.custom,
                onSelected: (v) {
                  if (v) setState(() => _preset = _PeriodPreset.custom);
                },
              ),
            ],
          ),
          if (_preset == _PeriodPreset.custom) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: true),
                    child: Text(
                      "${context.tr("reports_pick_start")}: ${DateFormat.yMMMd().format(_customStart!)}",
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: false),
                    child: Text(
                      "${context.tr("reports_pick_end")}: ${DateFormat.yMMMd().format(_customEnd!)}",
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          txsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text("${context.tr("error_prefix")} $e"),
            data: (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    context.trParams("reports_preview_count", {
                      "count": "${filtered.length}",
                    }),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      context.tr("reports_no_transactions"),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                Text(
                  context.tr("reports_actions_hint"),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _viewReport,
                      icon: const Icon(Icons.visibility_outlined),
                      label: Text(context.tr("reports_action_view")),
                    ),
                    OutlinedButton.icon(
                      onPressed: _downloadReport,
                      icon: const Icon(Icons.download_outlined),
                      label: Text(context.tr("reports_download_action")),
                    ),
                    OutlinedButton.icon(
                      onPressed: _printReport,
                      icon: const Icon(Icons.print_outlined),
                      label: Text(context.tr("reports_print")),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            context.tr("reports_team_section"),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          teamAsync.when(
            loading: () => const SizedBox(
              height: 24,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  context.tr("reports_team_empty"),
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }
              return Column(
                children: items.map((r) {
                  final subtitle = r.month.isNotEmpty
                      ? "${r.month} ${r.year}"
                      : "${r.year}";
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(r.title),
                    subtitle: Text(subtitle),
                    trailing: TextButton.icon(
                      onPressed: r.fileUrl.isEmpty
                          ? null
                          : () async {
                              final u = Uri.tryParse(r.fileUrl);
                              if (u == null) return;
                              if (await canLaunchUrl(u)) {
                                await launchUrl(
                                  u,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(context.tr("reports_open_link")),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
