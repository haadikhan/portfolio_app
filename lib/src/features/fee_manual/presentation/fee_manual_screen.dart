import "package:flutter/material.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_scaffold.dart";

class FeeManualScreen extends StatelessWidget {
  const FeeManualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: AppScaffold(
        title: context.tr("fee_manual_screen_title"),
        body: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: context.tr("fee_manual_tab_overview")),
                Tab(text: context.tr("fee_manual_tab_frontend")),
                Tab(text: context.tr("fee_manual_tab_management")),
                Tab(text: context.tr("fee_manual_tab_performance")),
                Tab(text: context.tr("fee_manual_tab_referral")),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _OverviewTab(),
                  _FrontendTab(),
                  _ManagementTab(),
                  _PerformanceTab(),
                  _ReferralTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Overview ────────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _OverviewFeeCard(
          icon: Icons.account_balance_wallet_rounded,
          title: context.tr("fee_manual_frontend_title"),
          description: context.tr("fee_manual_frontend_short"),
          rate: "2%",
          accentColor: scheme.error,
        ),
        _OverviewFeeCard(
          icon: Icons.settings_rounded,
          title: context.tr("fee_manual_mgmt_title"),
          description: context.tr("fee_manual_mgmt_short"),
          rate: "1.5% p.a.",
          accentColor: scheme.error,
        ),
        _OverviewFeeCard(
          icon: Icons.trending_up_rounded,
          title: context.tr("fee_manual_perf_title"),
          description: context.tr("fee_manual_perf_short"),
          rate: "15%",
          accentColor: scheme.error,
        ),
        _OverviewFeeCard(
          icon: Icons.people_rounded,
          title: context.tr("fee_manual_referral_title"),
          description: context.tr("fee_manual_referral_short"),
          rate: context.tr("fee_manual_referral_rate_varies"),
          accentColor: scheme.primary,
        ),
      ],
    );
  }
}

class _OverviewFeeCard extends StatelessWidget {
  const _OverviewFeeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.rate,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final String rate;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accentColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                rate,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Front-end tab ───────────────────────────────────────────────────────────

class _FrontendTab extends StatelessWidget {
  const _FrontendTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _FeeManualCard(
          title: context.tr("fee_manual_section_what"),
          icon: Icons.account_balance_wallet_rounded,
          content: Text(
            context.tr("fee_manual_frontend_what"),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        _FeeManualCard(
          title: context.tr("fee_manual_section_how_much"),
          icon: Icons.percent_rounded,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr("fee_manual_frontend_rate_value"),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              _ExampleBox(
                rows: [
                  (context.tr("fee_manual_fe_ex_deposit"), "PKR 10,000"),
                  (context.tr("fee_manual_fe_ex_fee"), "PKR 200 (2%)"),
                  (context.tr("fee_manual_fe_ex_invested"), "PKR 9,800"),
                ],
              ),
            ],
          ),
        ),
        _FeeManualCard(
          title: context.tr("fee_manual_section_when"),
          icon: Icons.schedule_rounded,
          content: Text(
            context.tr("fee_manual_frontend_when"),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        _FeeManualCard(
          title: context.tr("fee_manual_section_why"),
          icon: Icons.lightbulb_outline_rounded,
          content: Text(
            context.tr("fee_manual_frontend_why"),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

// ─── Management tab ────────────────────────────────────────────────────────────

class _ManagementTab extends StatelessWidget {
  const _ManagementTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _FeeManualCard(
          title: context.tr("fee_manual_section_what"),
          icon: Icons.settings_rounded,
          content: Text(
            context.tr("fee_manual_mgmt_what"),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        _FeeManualCard(
          title: context.tr("fee_manual_section_how_much"),
          icon: Icons.percent_rounded,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ExampleBox(
                rows: [
                  (context.tr("fee_manual_mgmt_ex_annual_label"), "1.5%"),
                  (
                    context.tr("fee_manual_mgmt_ex_daily_label"),
                    context.tr("fee_manual_mgmt_rate_daily_val"),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ExampleBox(
                rows: [
                  (context.tr("fee_manual_mgmt_ex_investment"), "PKR 100,000"),
                  (context.tr("fee_manual_mgmt_ex_annual"), "PKR 1,500"),
                  (context.tr("fee_manual_mgmt_ex_daily"), "PKR 4.11/day"),
                ],
              ),
            ],
          ),
        ),
        _FeeManualCard(
          title: context.tr("fee_manual_section_silent"),
          icon: Icons.info_outline,
          isWarning: true,
          content: Text(
            context.tr("fee_manual_mgmt_silent_note"),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        _FeeManualCard(
          title: context.tr("fee_manual_section_yearend"),
          icon: Icons.description_outlined,
          content: Text(
            context.tr("fee_manual_mgmt_yearend"),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        _FeeManualCard(
          title: context.tr("fee_manual_section_why"),
          icon: Icons.lightbulb_outline_rounded,
          content: Text(
            context.tr("fee_manual_mgmt_why"),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

// ─── Performance tab ───────────────────────────────────────────────────────────

class _PerformanceTab extends StatelessWidget {
  const _PerformanceTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _FeeManualCard(
          title: context.tr("fee_manual_section_what"),
          icon: Icons.trending_up_rounded,
          content: Text(
            context.tr("fee_manual_perf_what"),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        _FeeManualCard(
          title: context.tr("fee_manual_section_how_much"),
          icon: Icons.percent_rounded,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr("fee_manual_perf_rate_value"),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr("fee_manual_perf_rate_note"),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        _HwmStepsCard(),
        _FeeManualCard(
          title: context.tr("fee_manual_section_deposits"),
          icon: Icons.savings_outlined,
          content: Text(
            context.tr("fee_manual_perf_deposit_note"),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        _FeeManualCard(
          title: context.tr("fee_manual_section_why"),
          icon: Icons.lightbulb_outline_rounded,
          content: Text(
            context.tr("fee_manual_perf_why"),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _HwmStepsCard extends StatelessWidget {
  const _HwmStepsCard();

  @override
  Widget build(BuildContext context) {
    final steps = <List<String>>[
      [
        context.tr("fee_manual_hwm_step1_line1"),
        context.tr("fee_manual_hwm_step1_line2"),
        context.tr("fee_manual_hwm_step1_line3"),
      ],
      [
        context.tr("fee_manual_hwm_step2_line1"),
        context.tr("fee_manual_hwm_step2_line2"),
        context.tr("fee_manual_hwm_step2_line3"),
        context.tr("fee_manual_hwm_step2_line4"),
        context.tr("fee_manual_hwm_step2_line5"),
      ],
      [
        context.tr("fee_manual_hwm_step3_line1"),
        context.tr("fee_manual_hwm_step3_line2"),
        context.tr("fee_manual_hwm_step3_line3"),
      ],
      [
        context.tr("fee_manual_hwm_step4_line1"),
        context.tr("fee_manual_hwm_step4_line2"),
        context.tr("fee_manual_hwm_step4_line3"),
        context.tr("fee_manual_hwm_step4_line4"),
        context.tr("fee_manual_hwm_step4_line5"),
      ],
    ];

    return _FeeManualCard(
      title: context.tr("fee_manual_section_hwm"),
      icon: Icons.water_drop_outlined,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr("fee_manual_hwm_title"),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _HwmStepRow(stepNumber: i + 1, lines: steps[i]),
          ],
        ],
      ),
    );
  }
}

class _HwmStepRow extends StatelessWidget {
  const _HwmStepRow({required this.stepNumber, required this.lines});

  final int stepNumber;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: scheme.primaryContainer,
          child: Text(
            "$stepNumber",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Referral tab ──────────────────────────────────────────────────────────────

class _ReferralTab extends StatelessWidget {
  const _ReferralTab();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _FeeManualCard(
          title: context.tr("fee_manual_section_what"),
          icon: Icons.people_rounded,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr("fee_manual_referral_what"),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.tr("fee_manual_referral_badge"),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _FeeManualCard(
          title: context.tr("fee_manual_section_halving"),
          icon: Icons.table_chart_outlined,
          content: const _ReferralHalvingTable(),
        ),
        _FeeManualCard(
          title: context.tr("fee_manual_section_how"),
          icon: Icons.share_outlined,
          content: Text(
            context.tr("fee_manual_referral_how"),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _ReferralHalvingTable extends StatelessWidget {
  const _ReferralHalvingTable();

  static const _rowCount = 4;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 56,
        columnSpacing: 16,
        headingTextStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
        columns: [
          DataColumn(label: Text(context.tr("fee_manual_referral_col_deposit"))),
          DataColumn(label: Text(context.tr("fee_manual_referral_col_referrer"))),
          DataColumn(label: Text(context.tr("fee_manual_referral_col_company"))),
        ],
        rows: [
          for (var i = 0; i < _rowCount; i++)
            DataRow(
              cells: [
                DataCell(Text(_depositLabel(i))),
                DataCell(Text(_referrerLabel(context, i))),
                DataCell(Text(_companyLabel(context, i))),
              ],
            ),
        ],
      ),
    );
  }

  String _depositLabel(int index) {
    if (index < 3) return "${index + 1}";
    return "4+";
  }

  String _referrerLabel(BuildContext context, int index) {
    return switch (index) {
      0 => context.tr("fee_manual_ref_row1_referrer"),
      1 => context.tr("fee_manual_ref_row2_referrer"),
      2 => context.tr("fee_manual_ref_row3_referrer"),
      _ => context.tr("fee_manual_ref_row4_referrer"),
    };
  }

  String _companyLabel(BuildContext context, int index) {
    return switch (index) {
      0 => context.tr("fee_manual_ref_row1_company"),
      1 => context.tr("fee_manual_ref_row2_company"),
      2 => context.tr("fee_manual_ref_row3_company"),
      _ => context.tr("fee_manual_ref_row4_company"),
    };
  }
}

// ─── Shared widgets ────────────────────────────────────────────────────────────

class _FeeManualCard extends StatelessWidget {
  const _FeeManualCard({
    required this.title,
    required this.content,
    this.icon,
    this.isWarning = false,
  });

  final String title;
  final Widget content;
  final IconData? icon;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isWarning
          ? scheme.tertiaryContainer.withValues(alpha: 0.3)
          : scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isWarning
              ? scheme.tertiary.withValues(alpha: 0.4)
              : scheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            content,
          ],
        ),
      ),
    );
  }
}

class _ExampleBox extends StatelessWidget {
  const _ExampleBox({required this.rows});

  final List<(String label, String value)> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: rows
            .map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        r.$1,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      r.$2,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
