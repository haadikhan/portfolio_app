import "dart:typed_data";

import "package:file_saver/file_saver.dart";
import "package:flutter/foundation.dart"
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";
import "package:printing/printing.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../providers/auth_providers.dart";
import "../../../providers/reports_providers.dart";
import "../../../providers/transaction_history_providers.dart";
import "../data/fee_statement_providers.dart";
import "../services/report_pdf_builder.dart";
import "fee_statement_detail_screen.dart";
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
  bool _isDownloading = false;

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
    } catch (e, st) {
      debugPrint("[reports] buildInvestorReportPdf failed: $e\n$st");
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
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final bytes = await _buildPdfBytes();
      if (bytes == null || !mounted) return;

      final fileName = _pdfFileName();
      final base = fileName.replaceAll(".pdf", "");

      Future<bool> trySharePdf() async {
        try {
          await Printing.sharePdf(bytes: bytes, filename: fileName);
          return true;
        } catch (e, st) {
          debugPrint("[reports] sharePdf failed: $e\n$st");
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
          debugPrint("[reports] FileSaver.saveFile failed: $e\n$st");
          return false;
        }
      }

      // Android/iOS: share sheet first (user can save to Downloads / Files).
      // Web/desktop: FileSaver first (save dialog / browser download).
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

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageGradient = isDark
        ? [scheme.surface, scheme.surfaceContainerLowest]
        : [AppColors.backgroundTop, AppColors.backgroundBottom];

    Widget periodChip({
      required String label,
      required bool selected,
      required void Function(bool) onSelected,
    }) {
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.secondary,
        backgroundColor: scheme.surface,
        side: BorderSide(
          color: selected ? AppColors.primary : scheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
        labelStyle: TextStyle(
          color: selected ? AppColors.heading : scheme.onSurface,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        onSelected: onSelected,
      );
    }

    return AppScaffold(
      title: context.tr("reports_center_title"),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: pageGradient,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr("reports_select_period"),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                periodChip(
                  label: context.tr("reports_period_this_month"),
                  selected: _preset == _PeriodPreset.thisMonth,
                  onSelected: (v) {
                    if (v) setState(() => _preset = _PeriodPreset.thisMonth);
                  },
                ),
                periodChip(
                  label: context.tr("reports_period_this_year"),
                  selected: _preset == _PeriodPreset.thisYear,
                  onSelected: (v) {
                    if (v) setState(() => _preset = _PeriodPreset.thisYear);
                  },
                ),
                periodChip(
                  label: context.tr("reports_period_custom"),
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
              loading: () => Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: isDark ? 0.92 : 1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text("${context.tr("error_prefix")} $e"),
              data: (_) => Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: isDark ? 0.92 : 1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        context.trParams("reports_preview_count", {
                          "count": "${filtered.length}",
                        }),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.heading,
                            ),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
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
                        OutlinedButton(
                          onPressed: _isDownloading ? null : _downloadReport,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isDownloading)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                const Icon(Icons.download_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text(context.tr("reports_download_action")),
                            ],
                          ),
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
            ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            context.tr("fee_statement_section_title"),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr("fee_statement_section_subtitle"),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, _) {
              final feeAsync = ref.watch(userFeeStatementsProvider);
              return feeAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (e, _) => Text(
                  "${context.tr("error_prefix")} $e",
                  style: TextStyle(color: scheme.error),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Text(
                      context.tr("fee_statement_empty"),
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  }
                  return Column(
                    children: [
                      for (final s in items)
                        _FeeStatementRow(statement: s),
                    ],
                  );
                },
              );
            },
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
      ),
    );
  }
}

class _FeeStatementRow extends StatelessWidget {
  const _FeeStatementRow({required this.statement});
  final FeeStatement statement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);

    final parts = statement.periodKey.split("-");
    String monthLabel = statement.periodKey;
    if (parts.length == 2) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (y != null && m != null) {
        monthLabel = DateFormat.yMMMM().format(DateTime(y, m));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  FeeStatementDetailScreen(statement: statement),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: scheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${context.tr("fee_statement_total_fees")}: "
                      "${money.format(statement.totalFees)}"
                      " · "
                      "${context.tr("fee_statement_net_credited")}: "
                      "${money.format(statement.netProfit)}",
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
