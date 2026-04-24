import "package:fl_chart/fl_chart.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../providers/portfolio_providers.dart";
import "../../../providers/wallet_providers.dart";
import "../data/live_profit_providers.dart";
import "../domain/projected_profit_engine.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);
final _moneyLive = NumberFormat.currency(symbol: "PKR ", decimalDigits: 6);

class LiveProfitScreen extends ConsumerStatefulWidget {
  const LiveProfitScreen({super.key});

  @override
  ConsumerState<LiveProfitScreen> createState() => _LiveProfitScreenState();
}

class _LiveProfitScreenState extends ConsumerState<LiveProfitScreen> {
  LiveProfitRange _range = LiveProfitRange.minute;

  @override
  Widget build(BuildContext context) {
    final portfolioAsync = ref.watch(myPortfolioProvider);
    final walletAsync = ref.watch(userWalletStreamProvider);
    final firstDepositAtAsync = ref.watch(firstApprovedDepositAtProvider);
    final rateAsync = ref.watch(resolvedProjectionRateProvider);
    final nowAsync = ref.watch(liveProfitNowProvider);

    return AppScaffold(
      title: context.tr("live_profit_title"),
      body: nowAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text("${context.tr("error_prefix")} $e")),
        data: (now) => walletAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text("${context.tr("error_prefix")} $e")),
          data: (wallet) {
            final baseAmount = _readWalletBalance(wallet);
            if (baseAmount <= 0) {
              return Center(
                child: Text(context.tr("live_profit_no_wallet_data")),
              );
            }
            {
              final walletLastRecalculatedAt = _readWalletLastRecalculatedAt(wallet);
              final baseTimestamp =
                  firstDepositAtAsync.valueOrNull ??
                  walletLastRecalculatedAt ??
                  _readWalletTimestamp(wallet, "createdAt") ??
                  _readWalletTimestamp(wallet, "updatedAt") ??
                  portfolioAsync.valueOrNull?.createdAt ??
                  portfolioAsync.valueOrNull?.lastUpdated ??
                  now.subtract(const Duration(days: 30));
              final realizedProfit =
                  (wallet?["totalProfit"] as num?)?.toDouble() ?? 0;
              final annualRatePct = _resolveAnnualRatePct(
                resolvedRate: rateAsync.valueOrNull ?? 0,
                portfolioMonthlyPct:
                    portfolioAsync.valueOrNull?.lastMonthlyReturnPct ?? 0,
              );
              final snapshot = ProjectedProfitEngine.project(
                baseAmount: baseAmount,
                annualRatePct: annualRatePct,
                baseTimestamp: baseTimestamp,
                now: now,
              );
              final points = ProjectedProfitEngine.buildSeries(
                baseAmount: baseAmount,
                annualRatePct: annualRatePct,
                baseTimestamp: baseTimestamp,
                now: now,
                range: _range,
              );
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _HeroCard(
                    baseAmount: baseAmount,
                    projectedValue: snapshot.projectedValue,
                    projectedProfit: snapshot.projectedProfit,
                    realizedProfit: realizedProfit,
                    annualRatePct: annualRatePct,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _RangeChip(
                        label: context.tr("live_profit_filter_second"),
                        selected: _range == LiveProfitRange.second,
                        onTap: () =>
                            setState(() => _range = LiveProfitRange.second),
                      ),
                      _RangeChip(
                        label: context.tr("live_profit_filter_minute"),
                        selected: _range == LiveProfitRange.minute,
                        onTap: () =>
                            setState(() => _range = LiveProfitRange.minute),
                      ),
                      _RangeChip(
                        label: context.tr("live_profit_filter_day"),
                        selected: _range == LiveProfitRange.day,
                        onTap: () =>
                            setState(() => _range = LiveProfitRange.day),
                      ),
                      _RangeChip(
                        label: context.tr("live_profit_filter_month"),
                        selected: _range == LiveProfitRange.month,
                        onTap: () =>
                            setState(() => _range = LiveProfitRange.month),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _LiveChart(points: points),
                  const SizedBox(height: 14),
                  Text(
                    context.tr("live_profit_note_projected"),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.baseAmount,
    required this.projectedValue,
    required this.projectedProfit,
    required this.realizedProfit,
    required this.annualRatePct,
  });

  final double baseAmount;
  final double projectedValue;
  final double projectedProfit;
  final double realizedProfit;
  final double annualRatePct;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr("live_profit_projected_value"),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: projectedValue),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOut,
            builder: (context, value, _) => Text(
              _moneyLive.format(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr("live_profit_projected_profit"),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: projectedProfit),
                    duration: const Duration(milliseconds: 850),
                    curve: Curves.easeOut,
                    builder: (context, value, _) => Text(
                      _moneyLive.format(value),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    context.tr("live_profit_wallet_balance"),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    _money.format(baseAmount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr("live_profit_realized_profit"),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    _money.format(realizedProfit),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                context.trParams("live_profit_rate_info", {
                  "rate": annualRatePct.toStringAsFixed(2),
                }),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

double _readWalletBalance(Map<String, dynamic>? wallet) {
  if (wallet == null) return 0;
  final available = (wallet["availableBalance"] as num?)?.toDouble() ?? 0;
  if (available > 0) return available;
  final current = (wallet["currentBalance"] as num?)?.toDouble() ?? 0;
  if (current > 0) return current;
  final totalDeposited = (wallet["totalDeposited"] as num?)?.toDouble() ?? 0;
  final totalProfit = (wallet["totalProfit"] as num?)?.toDouble() ?? 0;
  final totalAdjustments =
      (wallet["totalAdjustments"] as num?)?.toDouble() ?? 0;
  final totalWithdrawn = (wallet["totalWithdrawn"] as num?)?.toDouble() ?? 0;
  final reserved = (wallet["reservedAmount"] as num?)?.toDouble() ?? 0;
  final computed =
      totalDeposited +
      totalProfit +
      totalAdjustments -
      totalWithdrawn -
      reserved;
  return computed.clamp(0, double.infinity);
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _LiveChart extends StatelessWidget {
  const _LiveChart({required this.points});

  final List<ProjectedChartPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final base = points.first.value;
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].value - base));
    }
    final minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final delta = (maxY - minY).abs();
    final pad = (delta > 0 ? delta * 0.2 : 0.01)
        .clamp(0.01, double.infinity)
        .toDouble();

    return Container(
      height: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: LineChart(
        LineChartData(
          minY: (minY - pad).clamp(0, double.infinity),
          maxY: (maxY + pad).clamp(0.02, double.infinity),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Theme.of(context).colorScheme.outlineVariant,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 58,
                getTitlesWidget: (value, _) => Text(
                  _compact(value),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (list) {
                return list.map((item) {
                  return LineTooltipItem(
                    _moneyLive.format(base + item.y),
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: AppColors.primary,
              barWidth: 2.5,
              isCurved: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.25),
                    AppColors.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _compact(double value) {
    if (value >= 100) return value.toStringAsFixed(2);
    if (value >= 10) return value.toStringAsFixed(3);
    return value.toStringAsFixed(4);
  }
}

DateTime? _readWalletLastRecalculatedAt(Map<String, dynamic>? wallet) {
  final raw = wallet?["lastRecalculatedAt"];
  if (raw is Timestamp) return raw.toDate();
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}

DateTime? _readWalletTimestamp(Map<String, dynamic>? wallet, String key) {
  final raw = wallet?[key];
  if (raw is Timestamp) return raw.toDate();
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}

double _resolveAnnualRatePct({
  required double resolvedRate,
  required double portfolioMonthlyPct,
}) {
  if (resolvedRate > 0) return resolvedRate;
  if (portfolioMonthlyPct > 0) {
    return (portfolioMonthlyPct * 12).clamp(0, 100).toDouble();
  }
  return 0;
}
