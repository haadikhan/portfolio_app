import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "package:portfolio_app/src/core/i18n/app_translations.dart";
import "package:portfolio_app/src/core/theme/app_colors.dart";

/// Bottom sheet for selecting a date range before downloading a sleeve report.
class ReportDateFilterSheet extends StatefulWidget {
  const ReportDateFilterSheet({
    super.key,
    required this.reportTitle,
    required this.onDownload,
  });

  final String reportTitle;

  /// Called when the user taps Download. Receives validated start and end dates.
  final Future<void> Function(DateTime start, DateTime end) onDownload;

  @override
  State<ReportDateFilterSheet> createState() => _ReportDateFilterSheetState();
}

class _ReportDateFilterSheetState extends State<ReportDateFilterSheet> {
  late DateTime _start;
  late DateTime _end;
  bool _isGenerating = false;
  String? _rangeError;

  static final _dateFmt = DateFormat("dd MMM yyyy");

  @override
  void initState() {
    super.initState();
    final today = _zeroed(DateTime.now());
    _start = today.subtract(const Duration(days: 30));
    _end = today;
  }

  static DateTime _zeroed(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = _zeroed(picked);
      } else {
        _end = _zeroed(picked);
      }
      _rangeError = _end.isBefore(_start)
          ? "${context.tr("sleeve_report_end_date")} must be after ${context.tr("sleeve_report_start_date")}"
          : null;
    });
  }

  Future<void> _submit() async {
    if (_end.isBefore(_start)) {
      setState(() {
        _rangeError =
            "${context.tr("sleeve_report_end_date")} must be after ${context.tr("sleeve_report_start_date")}";
      });
      return;
    }
    setState(() {
      _isGenerating = true;
      _rangeError = null;
    });
    try {
      await widget.onDownload(_start, _end);
      // Only close the sheet on success.
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // Error was already handled (snackbar shown) by the onDownload callback.
      // Swallow here so the sheet stays open and the user can retry.
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                context.tr("sleeve_report_filter_title"),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            _DateRow(
              label: context.tr("sleeve_report_start_date"),
              dateText: _dateFmt.format(_start),
              onTap: _isGenerating ? null : () => _pickDate(isStart: true),
              scheme: scheme,
            ),
            _DateRow(
              label: context.tr("sleeve_report_end_date"),
              dateText: _dateFmt.format(_end),
              onTap: _isGenerating ? null : () => _pickDate(isStart: false),
              scheme: scheme,
            ),
            if (_rangeError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  _rangeError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isGenerating
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _isGenerating ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(context.tr("sleeve_report_apply_btn")),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.dateText,
    required this.onTap,
    required this.scheme,
  });

  final String label;
  final String dateText;
  final VoidCallback? onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              dateText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
