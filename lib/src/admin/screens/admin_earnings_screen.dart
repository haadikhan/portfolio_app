import "package:cloud_firestore/cloud_firestore.dart";
import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../core/i18n/app_translations.dart";

const _kFeeTypes = <String>[
  "front_end_load_fee",
  "referral_fee",
  "management_fee",
  "performance_fee",
];

class _Earnings {
  const _Earnings({
    required this.frontLoad,
    required this.referral,
    required this.management,
    required this.performance,
  });
  final double frontLoad;
  final double referral;
  final double management;
  final double performance;
  double get total => frontLoad + referral + management + performance;

  _Earnings operator +(_Earnings o) => _Earnings(
        frontLoad: frontLoad + o.frontLoad,
        referral: referral + o.referral,
        management: management + o.management,
        performance: performance + o.performance,
      );

  static const zero = _Earnings(
    frontLoad: 0,
    referral: 0,
    management: 0,
    performance: 0,
  );
}

class _FeeTx {
  const _FeeTx({
    required this.userId,
    required this.type,
    required this.amount,
    required this.periodKey,
    required this.createdAt,
  });
  final String userId;
  final String type;
  final double amount;
  final String periodKey;
  final DateTime? createdAt;
}

final _feeTxStreamProvider =
    StreamProvider<List<_FeeTx>>((ref) {
  return FirebaseFirestore.instance
      .collection("transactions")
      .where("type", whereIn: _kFeeTypes)
      .orderBy("createdAt", descending: true)
      .limit(1000)
      .snapshots()
      .map((snap) {
    return snap.docs.map((doc) {
      final d = doc.data();
      final raw = d["createdAt"];
      DateTime? created;
      if (raw is Timestamp) created = raw.toDate();
      return _FeeTx(
        userId: (d["userId"] as String?) ?? "",
        type: (d["type"] as String?) ?? "",
        amount: (d["amount"] as num?)?.toDouble() ?? 0,
        periodKey: (d["periodKey"] as String?) ??
            (created != null
                ? "${created.year.toString().padLeft(4, '0')}-${created.month.toString().padLeft(2, '0')}"
                : ""),
        createdAt: created,
      );
    }).toList();
  });
});

class AdminEarningsScreen extends ConsumerStatefulWidget {
  const AdminEarningsScreen({super.key});

  @override
  ConsumerState<AdminEarningsScreen> createState() =>
      _AdminEarningsScreenState();
}

class _AdminEarningsScreenState extends ConsumerState<AdminEarningsScreen> {
  String? _selectedPeriod; // null = all
  String? _selectedKind; // null = all kinds

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);

    final txAsync = ref.watch(_feeTxStreamProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EarningsHeroHeader(),
          const SizedBox(height: 24),
          txAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text("${context.tr("error_prefix")} $e"),
            ),
            data: (all) {
              final now = DateTime.now();
              final ymThis = _ym(now);
              final yearStart = DateTime(now.year, 1, 1);

              _Earnings lifetime = _Earnings.zero;
              _Earnings thisMonth = _Earnings.zero;
              _Earnings ytd = _Earnings.zero;

              final byMonth = <String, _Earnings>{};
              final byUser = <String, _Earnings>{};
              final periodSet = <String>{};

              for (final t in all) {
                final delta = _toDelta(t.type, t.amount);
                lifetime = lifetime + delta;
                if (t.periodKey == ymThis) thisMonth = thisMonth + delta;
                if (t.createdAt != null && !t.createdAt!.isBefore(yearStart)) {
                  ytd = ytd + delta;
                }
                if (t.periodKey.isNotEmpty) {
                  periodSet.add(t.periodKey);
                  byMonth[t.periodKey] =
                      (byMonth[t.periodKey] ?? _Earnings.zero) + delta;
                }
                byUser[t.userId] =
                    (byUser[t.userId] ?? _Earnings.zero) + delta;
              }

              // Apply filters for the table.
              List<_FeeTx> filtered = all;
              if (_selectedPeriod != null) {
                filtered =
                    filtered.where((t) => t.periodKey == _selectedPeriod).toList();
              }
              if (_selectedKind != null) {
                filtered =
                    filtered.where((t) => t.type == _selectedKind).toList();
              }

              final sortedPeriods = periodSet.toList()..sort();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _KpiCard(
                        title: context.tr("earn_total_lifetime"),
                        value: money.format(lifetime.total),
                        icon: Icons.savings_rounded,
                        accent: const Color(0xFF1E88E5),
                      ),
                      _KpiCard(
                        title: context.tr("earn_this_month"),
                        value: money.format(thisMonth.total),
                        icon: Icons.calendar_today_rounded,
                        accent: const Color(0xFF00897B),
                      ),
                      _KpiCard(
                        title: context.tr("earn_ytd"),
                        value: money.format(ytd.total),
                        icon: Icons.event_repeat_rounded,
                        accent: const Color(0xFF6A1B9A),
                      ),
                      _KpiCard(
                        title: context.tr("earn_front_load_ytd"),
                        value: money.format(ytd.frontLoad),
                        icon: Icons.input_rounded,
                        accent: const Color(0xFF6A1B9A),
                      ),
                      _KpiCard(
                        title: context.tr("earn_referral_ytd"),
                        value: money.format(ytd.referral),
                        icon: Icons.handshake_outlined,
                        accent: const Color(0xFFEF6C00),
                      ),
                      _KpiCard(
                        title: context.tr("earn_mgmt_ytd"),
                        value: money.format(ytd.management),
                        icon: Icons.account_balance_outlined,
                        accent: const Color(0xFF1E88E5),
                      ),
                      _KpiCard(
                        title: context.tr("earn_perf_ytd"),
                        value: money.format(ytd.performance),
                        icon: Icons.trending_up_rounded,
                        accent: const Color(0xFF00897B),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    context.tr("earn_chart_title"),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _MonthlyStackedChart(byMonth: byMonth),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr("earn_filter_title"),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_selectedPeriod != null || _selectedKind != null)
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _selectedPeriod = null;
                            _selectedKind = null;
                          }),
                          icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                          label: Text(context.tr("earn_filter_clear")),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: context.tr("earn_filter_all_periods"),
                        active: _selectedPeriod == null,
                        onTap: () => setState(() => _selectedPeriod = null),
                      ),
                      ...sortedPeriods.reversed.take(12).map(
                            (p) => _FilterChip(
                              label: p,
                              active: _selectedPeriod == p,
                              onTap: () => setState(() => _selectedPeriod = p),
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: context.tr("earn_filter_all_kinds"),
                        active: _selectedKind == null,
                        onTap: () => setState(() => _selectedKind = null),
                      ),
                      _FilterChip(
                        label: context.tr("fee_label_front_load"),
                        active: _selectedKind == "front_end_load_fee",
                        onTap: () => setState(
                            () => _selectedKind = "front_end_load_fee"),
                      ),
                      _FilterChip(
                        label: context.tr("fee_label_referral"),
                        active: _selectedKind == "referral_fee",
                        onTap: () =>
                            setState(() => _selectedKind = "referral_fee"),
                      ),
                      _FilterChip(
                        label: context.tr("fee_label_management"),
                        active: _selectedKind == "management_fee",
                        onTap: () =>
                            setState(() => _selectedKind = "management_fee"),
                      ),
                      _FilterChip(
                        label: context.tr("fee_label_performance"),
                        active: _selectedKind == "performance_fee",
                        onTap: () =>
                            setState(() => _selectedKind = "performance_fee"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _TransactionsTable(items: filtered, money: money),
                  const SizedBox(height: 24),
                  Text(
                    context.tr("earn_per_investor_title"),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _InvestorBreakdownTable(byUser: byUser, money: money),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _ym(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}";

  _Earnings _toDelta(String type, double amount) {
    final amt = amount.abs();
    switch (type) {
      case "front_end_load_fee":
        return _Earnings(
            frontLoad: amt, referral: 0, management: 0, performance: 0);
      case "referral_fee":
        return _Earnings(
            frontLoad: 0, referral: amt, management: 0, performance: 0);
      case "management_fee":
        return _Earnings(
            frontLoad: 0, referral: 0, management: amt, performance: 0);
      case "performance_fee":
        return _Earnings(
            frontLoad: 0, referral: 0, management: 0, performance: amt);
      default:
        return _Earnings.zero;
    }
  }
}

class _EarningsHeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF134E5E), Color(0xFF71B280)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr("earnings_title"),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr("earnings_subtitle"),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
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
    return SizedBox(
      width: 240,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyStackedChart extends StatelessWidget {
  const _MonthlyStackedChart({required this.byMonth});
  final Map<String, _Earnings> byMonth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final months = byMonth.keys.toList()..sort();
    if (months.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.bar_chart_rounded, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(child: Text(context.tr("earn_chart_empty"))),
          ],
        ),
      );
    }
    final last12 =
        months.length > 12 ? months.sublist(months.length - 12) : months;
    final groups = <BarChartGroupData>[];
    double maxY = 0;
    for (var i = 0; i < last12.length; i++) {
      final e = byMonth[last12[i]] ?? _Earnings.zero;
      double rod = 0;
      final stack = <BarChartRodStackItem>[];

      void add(double value, Color color) {
        if (value <= 0) return;
        stack.add(BarChartRodStackItem(rod, rod + value, color));
        rod += value;
      }

      add(e.frontLoad, const Color(0xFF6A1B9A));
      add(e.referral, const Color(0xFFEF6C00));
      add(e.management, const Color(0xFF1E88E5));
      add(e.performance, const Color(0xFF00897B));

      if (rod > maxY) maxY = rod;
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: rod,
            width: 18,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4),
            ),
            rodStackItems: stack,
          ),
        ],
      ));
    }

    final yMax = maxY <= 0 ? 1.0 : maxY * 1.18;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _LegendDot(
                  color: const Color(0xFF6A1B9A),
                  label: context.tr("fee_label_front_load")),
              _LegendDot(
                  color: const Color(0xFFEF6C00),
                  label: context.tr("fee_label_referral")),
              _LegendDot(
                  color: const Color(0xFF1E88E5),
                  label: context.tr("fee_label_management")),
              _LegendDot(
                  color: const Color(0xFF00897B),
                  label: context.tr("fee_label_performance")),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                maxY: yMax,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, __) {
                      final period = last12[group.x];
                      return BarTooltipItem(
                        "$period\nPKR ${rod.toY.toStringAsFixed(0)}",
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, meta) {
                        if (v == 0) return const SizedBox.shrink();
                        String text;
                        if (v >= 1000000) {
                          text = "${(v / 1000000).toStringAsFixed(1)}M";
                        } else if (v >= 1000) {
                          text = "${(v / 1000).toStringAsFixed(0)}K";
                        } else {
                          text = v.toStringAsFixed(0);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            text,
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= last12.length) {
                          return const SizedBox.shrink();
                        }
                        final p = last12[i];
                        final label = p.length >= 7 ? p.substring(5) : p;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: groups,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? scheme.primary.withValues(alpha: 0.14)
              : scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? scheme.primary : scheme.outlineVariant,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _TransactionsTable extends StatelessWidget {
  const _TransactionsTable({required this.items, required this.money});
  final List<_FeeTx> items;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat("MMM d, yyyy HH:mm");
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.receipt_long_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(child: Text(context.tr("earn_table_empty"))),
          ],
        ),
      );
    }
    final shown = items.take(50).toList();
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: shown.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
        itemBuilder: (ctx, i) {
          final t = shown[i];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: _accent(t.type).withValues(alpha: 0.16),
              child: Icon(_icon(t.type), color: _accent(t.type), size: 18),
            ),
            title: Text(
              _label(context, t.type),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              "${t.userId.length > 12 ? "${t.userId.substring(0, 12)}…" : t.userId}"
              "${t.periodKey.isNotEmpty ? " · ${t.periodKey}" : ""}"
              "${t.createdAt != null ? " · ${dateFmt.format(t.createdAt!)}" : ""}",
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Text(
              "+ ${money.format(t.amount.abs())}",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.green.shade700,
              ),
            ),
          );
        },
      ),
    );
  }

  Color _accent(String ty) {
    switch (ty) {
      case "front_end_load_fee":
        return const Color(0xFF6A1B9A);
      case "referral_fee":
        return const Color(0xFFEF6C00);
      case "management_fee":
        return const Color(0xFF1E88E5);
      case "performance_fee":
        return const Color(0xFF00897B);
      default:
        return Colors.grey;
    }
  }

  IconData _icon(String ty) {
    switch (ty) {
      case "front_end_load_fee":
        return Icons.input_rounded;
      case "referral_fee":
        return Icons.handshake_outlined;
      case "management_fee":
        return Icons.account_balance_outlined;
      case "performance_fee":
        return Icons.trending_up_rounded;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  String _label(BuildContext context, String ty) {
    switch (ty) {
      case "front_end_load_fee":
        return context.tr("fee_label_front_load");
      case "referral_fee":
        return context.tr("fee_label_referral");
      case "management_fee":
        return context.tr("fee_label_management");
      case "performance_fee":
        return context.tr("fee_label_performance");
      default:
        return ty;
    }
  }
}

class _InvestorBreakdownTable extends StatelessWidget {
  const _InvestorBreakdownTable({required this.byUser, required this.money});
  final Map<String, _Earnings> byUser;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = byUser.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));
    final shown = entries.take(20).toList();
    if (shown.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.people_outline, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(child: Text(context.tr("earn_per_investor_empty"))),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 38,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 44,
          columns: [
            DataColumn(label: Text(context.tr("earn_col_investor"))),
            DataColumn(
                label: Text(context.tr("fee_label_front_load")),
                numeric: true),
            DataColumn(
                label: Text(context.tr("fee_label_referral")), numeric: true),
            DataColumn(
                label: Text(context.tr("fee_label_management")), numeric: true),
            DataColumn(
                label: Text(context.tr("fee_label_performance")), numeric: true),
            DataColumn(
                label: Text(context.tr("earn_col_total")), numeric: true),
          ],
          rows: [
            for (final e in shown)
              DataRow(cells: [
                DataCell(
                  Text(
                    e.key.length > 14 ? "${e.key.substring(0, 14)}…" : e.key,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(Text(money.format(e.value.frontLoad),
                    style: const TextStyle(fontSize: 12))),
                DataCell(Text(money.format(e.value.referral),
                    style: const TextStyle(fontSize: 12))),
                DataCell(Text(money.format(e.value.management),
                    style: const TextStyle(fontSize: 12))),
                DataCell(Text(money.format(e.value.performance),
                    style: const TextStyle(fontSize: 12))),
                DataCell(Text(
                  money.format(e.value.total),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                )),
              ]),
          ],
        ),
      ),
    );
  }
}
