import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../core/i18n/app_translations.dart";

const _kLedgerFeeTypes = <String>[
  "front_end_load",
  "referral_commission",
  "management_daily",
  "performance_hwm",
];

class _LedgerEntry {
  const _LedgerEntry({
    required this.id,
    required this.date,
    required this.investorUid,
    required this.feeType,
    required this.grossFeePkr,
    required this.referralSharePkr,
    required this.netToCompanyPkr,
    this.referrerName,
    required this.createdAt,
  });

  final String id;
  final String date;
  final String investorUid;
  final String feeType;
  final double grossFeePkr;
  final double referralSharePkr;
  final double netToCompanyPkr;
  final String? referrerName;
  final DateTime? createdAt;
}

final _ledgerStreamProvider =
    StreamProvider<List<_LedgerEntry>>((ref) {
  return FirebaseFirestore.instance
      .collection("company_fee_ledger")
      .orderBy("createdAt", descending: true)
      .limit(500)
      .snapshots()
      .map((snap) => snap.docs.map((doc) {
            final d = doc.data();
            DateTime? t;
            final raw = d["createdAt"];
            if (raw is Timestamp) t = raw.toDate();
            return _LedgerEntry(
              id: doc.id,
              date: (d["date"] as String?) ?? "",
              investorUid: (d["investorUid"] as String?) ?? "",
              feeType: (d["feeType"] as String?) ?? "",
              grossFeePkr:
                  (d["grossFeePkr"] as num?)?.toDouble() ?? 0,
              referralSharePkr:
                  (d["referralSharePkr"] as num?)?.toDouble() ?? 0,
              netToCompanyPkr:
                  (d["netToCompanyPkr"] as num?)?.toDouble() ?? 0,
              referrerName: d["referrerName"] as String?,
              createdAt: t,
            );
          }).toList());
});

class AdminCompanyFeeLedgerScreen extends ConsumerStatefulWidget {
  const AdminCompanyFeeLedgerScreen({super.key});

  @override
  ConsumerState<AdminCompanyFeeLedgerScreen> createState() =>
      _AdminCompanyFeeLedgerScreenState();
}

class _AdminCompanyFeeLedgerScreenState
    extends ConsumerState<AdminCompanyFeeLedgerScreen> {
  String? _selectedType;
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final money =
        NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);
    final ledgerAsync = ref.watch(_ledgerStreamProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero header ──────────────────────────────────────
          _LedgerHeroHeader(),
          const SizedBox(height: 24),

          ledgerAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${context.tr("error_prefix")} $e",
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            data: (all) {
              double totalGross = 0;
              double totalReferral = 0;
              double totalNet = 0;
              for (final e in all) {
                totalGross += e.grossFeePkr;
                totalReferral += e.referralSharePkr;
                totalNet += e.netToCompanyPkr;
              }

              List<_LedgerEntry> filtered = all;
              if (_selectedType != null) {
                filtered = filtered
                    .where((e) => e.feeType == _selectedType)
                    .toList();
              }
              if (_dateRange != null) {
                filtered = filtered.where((e) {
                  if (e.createdAt == null) return false;
                  return !e.createdAt!
                          .isBefore(_dateRange!.start) &&
                      !e.createdAt!.isAfter(
                        _dateRange!.end
                            .add(const Duration(days: 1)),
                      );
                }).toList();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Totals ──────────────────────────────────
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _KpiCard(
                        title: context.tr("fee_ledger_total_gross"),
                        value: money.format(totalGross),
                        icon: Icons.account_balance_wallet_outlined,
                        accent: const Color(0xFF1E88E5),
                      ),
                      _KpiCard(
                        title: context.tr("fee_ledger_total_referral"),
                        value: money.format(totalReferral),
                        icon: Icons.handshake_outlined,
                        accent: const Color(0xFFEF6C00),
                      ),
                      _KpiCard(
                        title: context.tr("fee_ledger_net_company"),
                        value: money.format(totalNet),
                        icon: Icons.savings_outlined,
                        accent: const Color(0xFF00897B),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Filters ──────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterChip(
                                label:
                                    context.tr("fee_ledger_filter_all"),
                                selected: _selectedType == null,
                                onTap: () =>
                                    setState(() => _selectedType = null),
                              ),
                              const SizedBox(width: 8),
                              for (final type in _kLedgerFeeTypes)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(right: 8),
                                  child: _FilterChip(
                                    label: _feeTypeLabel(
                                        context, type),
                                    selected: _selectedType == type,
                                    onTap: () => setState(
                                        () => _selectedType = type),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2024),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 1)),
                            initialDateRange: _dateRange,
                          );
                          if (picked != null) {
                            setState(() => _dateRange = picked);
                          }
                        },
                        icon: const Icon(Icons.date_range_outlined,
                            size: 18),
                        label: Text(
                          _dateRange == null
                              ? context.tr(
                                  "fee_ledger_filter_date")
                              : "${DateFormat("d MMM").format(_dateRange!.start)} – "
                                  "${DateFormat("d MMM yy").format(_dateRange!.end)}",
                        ),
                      ),
                      if (_dateRange != null) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: "Clear date",
                          onPressed: () =>
                              setState(() => _dateRange = null),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Table ────────────────────────────────────
                  Text(
                    "${filtered.length} ${context.tr("fee_ledger_entries_label")}",
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          context.tr("fee_ledger_empty"),
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                            color: scheme.outlineVariant),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            scheme.surfaceContainerHighest,
                          ),
                          columns: [
                            DataColumn(
                                label: Text(context
                                    .tr("fee_ledger_col_date"))),
                            DataColumn(
                                label: Text(context.tr(
                                    "fee_ledger_col_investor"))),
                            DataColumn(
                                label: Text(context
                                    .tr("fee_ledger_col_type"))),
                            DataColumn(
                                label: Text(context
                                    .tr("fee_ledger_col_gross")),
                                numeric: true),
                            DataColumn(
                                label: Text(context
                                    .tr("fee_ledger_col_referral")),
                                numeric: true),
                            DataColumn(
                                label: Text(context
                                    .tr("fee_ledger_net_company")),
                                numeric: true),
                            DataColumn(
                                label: Text(context
                                    .tr("fee_ledger_col_referrer"))),
                          ],
                          rows: filtered
                              .map(
                                (e) => DataRow(cells: [
                                  DataCell(Text(e.date.isEmpty
                                      ? "—"
                                      : e.date)),
                                  DataCell(Text(
                                    e.investorUid.length > 10
                                        ? "…${e.investorUid.substring(e.investorUid.length - 8)}"
                                        : e.investorUid,
                                  )),
                                  DataCell(
                                    _FeeTypeChip(
                                        feeType: e.feeType),
                                  ),
                                  DataCell(Text(
                                      money.format(e.grossFeePkr))),
                                  DataCell(Text(e.referralSharePkr > 0
                                      ? money.format(
                                          e.referralSharePkr)
                                      : "—")),
                                  DataCell(Text(money
                                      .format(e.netToCompanyPkr))),
                                  DataCell(Text(
                                      e.referrerName?.isNotEmpty ==
                                              true
                                          ? e.referrerName!
                                          : "—")),
                                ]),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _feeTypeLabel(BuildContext context, String type) {
    switch (type) {
      case "front_end_load":
        return context.tr("fee_label_front_load");
      case "referral_commission":
        return context.tr("fee_label_referral");
      case "management_daily":
        return context.tr("fee_label_management");
      case "performance_hwm":
        return context.tr("fee_label_performance");
      default:
        return type;
    }
  }
}

class _LedgerHeroHeader extends StatelessWidget {
  const _LedgerHeroHeader();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                  Color(0xFF2C5364),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: isDark ? 0.45 : 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr("fee_ledger_nav"),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr("fee_ledger_subtitle"),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });
  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style:
                      Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _FeeTypeChip extends StatelessWidget {
  const _FeeTypeChip({required this.feeType});
  final String feeType;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (feeType) {
      "front_end_load" => (
          const Color(0xFF6A1B9A),
          "Front-end"
        ),
      "referral_commission" => (
          const Color(0xFFEF6C00),
          "Referral"
        ),
      "management_daily" => (
          const Color(0xFF1E88E5),
          "Management"
        ),
      "performance_hwm" => (
          const Color(0xFF00897B),
          "Performance"
        ),
      _ => (Colors.grey, feeType),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
