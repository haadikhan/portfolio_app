import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../providers/portfolio_providers.dart";
import "../../../providers/wallet_providers.dart";
import "../../market/providers/kmi30_index_provider.dart";
import "../data/allocation_money_market.dart";
import "../domain/five_market_models.dart";
import "../providers/five_market_live_profit_provider.dart";
import "../providers/market_sleeve_balance_provider.dart";
import "../providers/five_market_providers.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);
final _moneyLive = NumberFormat.currency(symbol: "PKR ", decimalDigits: 6);
final _monthYearFmt = DateFormat("MMMM yyyy");

const _kStockColor = Color(0xFF0F7A2C);
const _kTechColor = Color(0xFF2196F3);
const _kDebtColor = Color(0xFFFF9800);
const _kMoneyColor = Color(0xFF9C27B0);
const _kGoldColor = Color(0xFFE91E63);

Future<void> _onLiveProfitRefresh(WidgetRef ref) async {
  ref.invalidate(fiveMarketLiveProfitProvider);
  ref.invalidate(fiveMarketDailyHistoryProvider);
  ref.invalidate(kmi30IndexTickProvider);
  await Future<void>.delayed(const Duration(milliseconds: 800));
}

double _localFixedProfit({
  required double allocatedPkr,
  required double annualPercent,
  required int elapsedSec,
}) {
  if (elapsedSec <= 0) return 0;
  final daily = allocatedPkr * annualPercent / 100 / 365;
  return double.parse((daily / 25200 * elapsedSec).toStringAsFixed(2));
}

double _displayDailyTotal(FiveMarketLiveProfitState live, int elapsedSec) {
  if (!live.isTradingDay) return 0;
  return double.parse(
    (
      live.stockProfitPkr +
      _localFixedProfit(
        allocatedPkr: live.techAllocatedPkr,
        annualPercent: live.techAnnualPercent,
        elapsedSec: elapsedSec,
      ) +
      _localFixedProfit(
        allocatedPkr: live.debtAllocatedPkr,
        annualPercent: live.debtAnnualPercent,
        elapsedSec: elapsedSec,
      ) +
      _localFixedProfit(
        allocatedPkr: live.moneyAllocatedPkr,
        annualPercent: live.moneyAnnualPercent,
        elapsedSec: elapsedSec,
      ) +
      live.goldProfitPkr
    ).toStringAsFixed(2),
  );
}

// ── Daily tab countdown (PKT, UTC+5) ─────────────────────────────────────────

enum _CountdownPhase {
  marketOpen,
  awaitingCredit,
  preMarketOpen,
  nonTradingDay,
  nonTradingDayNoCredit,
  creditJustRan,
}

class _CountdownInfo {
  const _CountdownInfo({
    required this.phase,
    required this.remaining,
    required this.isTradingDay,
  });

  final _CountdownPhase phase;
  final Duration remaining;
  final bool isTradingDay;
}

/// PKT wall-clock (h,m) on calendar [y]-[m]-[d] → UTC instant.
DateTime _pktWallToUtc(int y, int m, int d, int pktHour, int pktMin) {
  return DateTime.utc(y, m, d, pktHour - 5, pktMin);
}

/// Next PKT clock time at [pktHour]:[pktMin] strictly after [nowUtc].
DateTime _nextPktInstantUtc(
  DateTime nowUtc,
  DateTime nowPkt,
  int pktHour,
  int pktMin,
) {
  var target = _pktWallToUtc(nowPkt.year, nowPkt.month, nowPkt.day, pktHour, pktMin);
  if (!target.isAfter(nowUtc)) {
    final nextPkt = nowPkt.add(const Duration(days: 1));
    target = _pktWallToUtc(
      nextPkt.year,
      nextPkt.month,
      nextPkt.day,
      pktHour,
      pktMin,
    );
  }
  return target;
}

_CountdownInfo _resolveCountdown(bool isTradingDay) {
  final nowUtc = DateTime.now().toUtc();
  final nowPkt = nowUtc.add(const Duration(hours: 5));
  final h = nowPkt.hour;
  final m = nowPkt.minute;

  if (h == 0 && m < 5) {
    return _CountdownInfo(
      phase: _CountdownPhase.creditJustRan,
      remaining: Duration.zero,
      isTradingDay: isTradingDay,
    );
  }

  if (h < 9) {
    final target = _nextPktInstantUtc(nowUtc, nowPkt, 9, 0);
    return _CountdownInfo(
      phase: _CountdownPhase.preMarketOpen,
      remaining: target.difference(nowUtc),
      isTradingDay: isTradingDay,
    );
  }

  if (h >= 9 && h < 16) {
    if (!isTradingDay) {
      return const _CountdownInfo(
        phase: _CountdownPhase.nonTradingDay,
        remaining: Duration.zero,
        isTradingDay: false,
      );
    }
    final target = _nextPktInstantUtc(nowUtc, nowPkt, 16, 0);
    return _CountdownInfo(
      phase: _CountdownPhase.marketOpen,
      remaining: target.difference(nowUtc),
      isTradingDay: true,
    );
  }

  if (!isTradingDay) {
    return const _CountdownInfo(
      phase: _CountdownPhase.nonTradingDayNoCredit,
      remaining: Duration.zero,
      isTradingDay: false,
    );
  }

  final nextPkt = nowPkt.add(const Duration(days: 1));
  final creditTarget = _pktWallToUtc(
    nextPkt.year,
    nextPkt.month,
    nextPkt.day,
    0,
    5,
  );
  return _CountdownInfo(
    phase: _CountdownPhase.awaitingCredit,
    remaining: creditTarget.difference(nowUtc),
    isTradingDay: true,
  );
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.info});

  final _CountdownInfo info;

  String _formatDuration(Duration d) {
    if (d.isNegative || d == Duration.zero) return "00:00:00";
    final h = d.inHours.toString().padLeft(2, "0");
    final m = (d.inMinutes % 60).toString().padLeft(2, "0");
    final s = (d.inSeconds % 60).toString().padLeft(2, "0");
    return "$h:$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (info.phase == _CountdownPhase.nonTradingDay ||
        info.phase == _CountdownPhase.nonTradingDayNoCredit) {
      final messageKey = info.phase == _CountdownPhase.nonTradingDayNoCredit
          ? "countdown_no_credit_tonight"
          : "countdown_non_trading_day";
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.event_busy_rounded,
                color: scheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr(messageKey),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (info.phase == _CountdownPhase.creditJustRan) {
      return Card(
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                context.tr("countdown_processing"),
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final accentColor = switch (info.phase) {
      _CountdownPhase.marketOpen => scheme.primary,
      _CountdownPhase.awaitingCredit => scheme.tertiary,
      _CountdownPhase.preMarketOpen => scheme.onSurfaceVariant,
      _ => scheme.onSurfaceVariant,
    };

    final icon = switch (info.phase) {
      _CountdownPhase.marketOpen => Icons.trending_up_rounded,
      _CountdownPhase.awaitingCredit => Icons.account_balance_wallet_outlined,
      _CountdownPhase.preMarketOpen => Icons.schedule_rounded,
      _ => Icons.schedule_rounded,
    };

    final labelKey = switch (info.phase) {
      _CountdownPhase.marketOpen => "countdown_market_closes",
      _CountdownPhase.awaitingCredit => "countdown_profit_credits",
      _CountdownPhase.preMarketOpen => "countdown_market_opens",
      _ => "countdown_market_opens",
    };

    final chipKey = switch (info.phase) {
      _CountdownPhase.marketOpen => "countdown_live_chip",
      _CountdownPhase.awaitingCredit => "countdown_pending_chip",
      _CountdownPhase.preMarketOpen => "countdown_premarket_chip",
      _ => "",
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: accentColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(labelKey),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDuration(info.remaining),
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (chipKey.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  context.tr(chipKey),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LiveProfitScreen extends ConsumerWidget {
  const LiveProfitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(userWalletStreamProvider);
    final baseAmount = walletAsync.valueOrNull != null
        ? allocationTotalFromWallet(walletAsync.valueOrNull)
        : 0.0;

    if (walletAsync.isLoading) {
      return AppScaffold(
        title: context.tr("live_profit_title"),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (walletAsync.hasError) {
      return AppScaffold(
        title: context.tr("live_profit_title"),
        body: Center(
          child: Text("${context.tr("error_prefix")} ${walletAsync.error}"),
        ),
      );
    }
    if (baseAmount <= 0) {
      return AppScaffold(
        title: context.tr("live_profit_title"),
        body: Center(child: Text(context.tr("live_profit_no_wallet_data"))),
      );
    }

    return AppScaffold(
      title: context.tr("live_profit_title"),
      body: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              tabs: [
                Tab(text: context.tr("profit_tab_daily")),
                Tab(text: context.tr("profit_tab_monthly")),
                Tab(text: context.tr("profit_tab_yearly")),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _DailyTab(wallet: walletAsync.valueOrNull),
                  _MonthlyTab(wallet: walletAsync.valueOrNull),
                  _YearlyTab(wallet: walletAsync.valueOrNull),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Daily tab ───────────────────────────────────────────────────────────────

class _DailyTab extends ConsumerStatefulWidget {
  const _DailyTab({required this.wallet});

  final Map<String, dynamic>? wallet;

  @override
  ConsumerState<_DailyTab> createState() => _DailyTabState();
}

class _DailyTabState extends ConsumerState<_DailyTab> {
  late Timer _ticker;
  int _elapsedSec = 0;
  late _CountdownInfo _countdownInfo;

  @override
  void initState() {
    super.initState();
    _elapsedSec = elapsedSessionSeconds();
    _countdownInfo = _resolveCountdown(
      ref.read(todayTradingDayProvider).isTradingDay,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsedSec = elapsedSessionSeconds();
          _countdownInfo = _resolveCountdown(
            ref.read(todayTradingDayProvider).isTradingDay,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(myPortfolioProvider);
    final liveProfitAsync = ref.watch(fiveMarketLiveProfitProvider);
    final tradingDay = ref.watch(todayTradingDayProvider);
    final wallet = widget.wallet;
    final baseAmount = allocationTotalFromWallet(wallet);
    final realizedProfit = (wallet?["totalProfit"] as num?)?.toDouble() ?? 0;
    final scheme = Theme.of(context).colorScheme;

    return liveProfitAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text("${context.tr("error_prefix")} $e")),
      data: (live) {
        final techDisplay = _localFixedProfit(
          allocatedPkr: live.techAllocatedPkr,
          annualPercent: live.techAnnualPercent,
          elapsedSec: _elapsedSec,
        );
        final debtDisplay = _localFixedProfit(
          allocatedPkr: live.debtAllocatedPkr,
          annualPercent: live.debtAnnualPercent,
          elapsedSec: _elapsedSec,
        );
        final moneyDisplay = _localFixedProfit(
          allocatedPkr: live.moneyAllocatedPkr,
          annualPercent: live.moneyAnnualPercent,
          elapsedSec: _elapsedSec,
        );
        final totalDisplay = _displayDailyTotal(live, _elapsedSec);

        return RefreshIndicator(
          onRefresh: () => _onLiveProfitRefresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _HeroCard(
                basePkr: live.basePkr,
                totalProfitPkr: totalDisplay,
                realizedProfit: realizedProfit,
                walletBalance: baseAmount,
              ),
              const SizedBox(height: 12),
              _CountdownCard(info: _countdownInfo),
              const SizedBox(height: 12),
              _MarketStatusRow(live: live),
              if (!live.isTradingDay) ...[
                const SizedBox(height: 12),
                _ClosedDayBanner(
                  tradingDay: tradingDay,
                  scheme: scheme,
                ),
              ],
              const SizedBox(height: 14),
              _MarketBreakdownCard(
                labelKey: "five_market_row_stock",
                status: live.stockStatus,
                allocatedPkr: live.stockAllocatedPkr,
                profitPkr: live.stockProfitPkr,
                changePercent: live.kmi30ChangePercent,
                subLabel: context.tr("live_profit_kmi30_sub"),
                annualRateLabel: null,
                icon: Icons.show_chart_rounded,
              ),
              const SizedBox(height: 10),
              _MarketBreakdownCard(
                labelKey: "five_market_row_tech",
                status: live.techStatus,
                allocatedPkr: live.techAllocatedPkr,
                profitPkr: techDisplay,
                changePercent: null,
                subLabel: context.tr("live_profit_fixed_sub"),
                annualRateLabel:
                    "${live.techAnnualPercent.toStringAsFixed(0)}% ${context.tr("five_market_per_annum")} benchmark",
                icon: Icons.memory_rounded,
              ),
              const SizedBox(height: 10),
              _MarketBreakdownCard(
                labelKey: "five_market_row_debt",
                status: live.debtStatus,
                allocatedPkr: live.debtAllocatedPkr,
                profitPkr: debtDisplay,
                changePercent: null,
                subLabel: context.tr("live_profit_fixed_sub"),
                annualRateLabel:
                    "${live.debtAnnualPercent.toStringAsFixed(1)}% ${context.tr("five_market_per_annum")}",
                icon: Icons.account_balance_rounded,
              ),
              const SizedBox(height: 10),
              _MarketBreakdownCard(
                labelKey: "five_market_row_money",
                status: live.moneyStatus,
                allocatedPkr: live.moneyAllocatedPkr,
                profitPkr: moneyDisplay,
                changePercent: null,
                subLabel: context.tr("live_profit_fixed_sub"),
                annualRateLabel:
                    "${live.moneyAnnualPercent.toStringAsFixed(1)}% ${context.tr("five_market_per_annum")}",
                icon: Icons.account_balance_wallet_rounded,
              ),
              const SizedBox(height: 10),
              _MarketBreakdownCard(
                labelKey: "five_market_row_gold",
                status: live.goldStatus,
                allocatedPkr: live.goldAllocatedPkr,
                profitPkr: live.goldProfitPkr,
                changePercent: live.goldChangePercent,
                subLabel: context.tr("live_profit_gold_sub"),
                annualRateLabel: null,
                icon: Icons.diamond_outlined,
              ),
              const SizedBox(height: 14),
              _TotalProfitCard(totalProfitPkr: totalDisplay),
              const SizedBox(height: 14),
              Text(
                context.tr("live_profit_note_five_market"),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Monthly tab ─────────────────────────────────────────────────────────────

class _MonthlyTab extends ConsumerWidget {
  const _MonthlyTab({required this.wallet});

  final Map<String, dynamic>? wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(fiveMarketMonthlyProfitProvider);
    final realizedProfit = (wallet?["totalProfit"] as num?)?.toDouble() ?? 0;
    final nowPkt = DateTime.now().toUtc().add(const Duration(hours: 5));
    final monthLabel = _monthYearFmt.format(nowPkt);
    final totalToShow = summary.displayTotalPkr;

    return RefreshIndicator(
      onRefresh: () => _onLiveProfitRefresh(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _PeriodHeaderCard(
            title: context.tr("profit_period_month_to_date"),
            subtitle: monthLabel,
            tradingDays: summary.tradingDays,
            tradingDaysSuffix: context.tr("profit_trading_days"),
          ),
          const SizedBox(height: 16),
          _PeriodHeroCard(
            totalProfitPkr: totalToShow,
            label: context.tr("profit_net_pl"),
          ),
          const SizedBox(height: 16),
          if (!summary.isFromLedger)
            const _LedgerNotReadyCard()
          else ...[
            _PeriodMarketList(
              summary: summary,
              priceDrivenLabel: context.tr("profit_price_driven"),
              fixedAccrualLabel: context.tr("profit_fixed_accrual"),
            ),
            const SizedBox(height: 14),
            Text(
              context.tr("profit_includes_today"),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
            const SizedBox(height: 16),
            _AllTimeProfitRow(amount: realizedProfit),
          ],
        ],
      ),
    );
  }
}

// ── Yearly tab ──────────────────────────────────────────────────────────────

class _YearlyTab extends ConsumerWidget {
  const _YearlyTab({required this.wallet});

  final Map<String, dynamic>? wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(fiveMarketYearlyProfitProvider);
    final realizedProfit = (wallet?["totalProfit"] as num?)?.toDouble() ?? 0;
    final nowPkt = DateTime.now().toUtc().add(const Duration(hours: 5));
    final yearLabel = nowPkt.year.toString();
    final totalToShow = summary.displayTotalPkr;

    return RefreshIndicator(
      onRefresh: () => _onLiveProfitRefresh(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _PeriodHeaderCard(
            title: context.tr("profit_period_year_to_date"),
            subtitle: yearLabel,
            tradingDays: summary.tradingDays,
            tradingDaysSuffix: context.tr("profit_trading_days_year"),
          ),
          const SizedBox(height: 16),
          _PeriodHeroCard(
            totalProfitPkr: totalToShow,
            label: context.tr("profit_net_pl"),
          ),
          const SizedBox(height: 16),
          if (!summary.isFromLedger)
            const _LedgerNotReadyCard()
          else ...[
            _PeriodMarketList(
              summary: summary,
              priceDrivenLabel: context.tr("profit_price_driven"),
              fixedAccrualLabel: context.tr("profit_fixed_accrual"),
            ),
            const SizedBox(height: 16),
            _YearlyContributionBars(summary: summary),
            const SizedBox(height: 14),
            _BestWorstMarkets(summary: summary),
            const SizedBox(height: 16),
            _AllTimeProfitRow(amount: realizedProfit),
          ],
        ],
      ),
    );
  }
}

// ── Shared period widgets ───────────────────────────────────────────────────

class _LedgerNotReadyCard extends StatelessWidget {
  const _LedgerNotReadyCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: scheme.primary,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr("profit_ledger_not_ready"),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodHeaderCard extends StatelessWidget {
  const _PeriodHeaderCard({
    required this.title,
    required this.subtitle,
    required this.tradingDays,
    required this.tradingDaysSuffix,
  });

  final String title;
  final String subtitle;
  final int tradingDays;
  final String tradingDaysSuffix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "$tradingDays $tradingDaysSuffix",
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodHeroCard extends StatelessWidget {
  const _PeriodHeroCard({
    required this.totalProfitPkr,
    required this.label,
  });

  final double totalProfitPkr;
  final String label;

  @override
  Widget build(BuildContext context) {
    final valueColor = totalProfitPkr < 0 ? Colors.red.shade200 : Colors.white;
    return Container(
      width: double.infinity,
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
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: totalProfitPkr),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOut,
            builder: (context, value, _) => Text(
              "${value >= 0 ? "+" : ""}${_moneyLive.format(value)}",
              style: TextStyle(
                color: valueColor,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodMarketList extends StatelessWidget {
  const _PeriodMarketList({
    required this.summary,
    required this.priceDrivenLabel,
    required this.fixedAccrualLabel,
  });

  final FiveMarketPeriodSummary summary;
  final String priceDrivenLabel;
  final String fixedAccrualLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PeriodMarketTile(
          labelKey: "five_market_row_stock",
          profitPkr: summary.stockProfitPkr,
          subLabel: priceDrivenLabel,
          color: _kStockColor,
          icon: Icons.show_chart_rounded,
        ),
        const SizedBox(height: 10),
        _PeriodMarketTile(
          labelKey: "five_market_row_tech",
          profitPkr: summary.techProfitPkr,
          subLabel: fixedAccrualLabel,
          color: _kTechColor,
          icon: Icons.memory_rounded,
        ),
        const SizedBox(height: 10),
        _PeriodMarketTile(
          labelKey: "five_market_row_debt",
          profitPkr: summary.debtProfitPkr,
          subLabel: fixedAccrualLabel,
          color: _kDebtColor,
          icon: Icons.account_balance_rounded,
        ),
        const SizedBox(height: 10),
        _PeriodMarketTile(
          labelKey: "five_market_row_money",
          profitPkr: summary.moneyProfitPkr,
          subLabel: fixedAccrualLabel,
          color: _kMoneyColor,
          icon: Icons.account_balance_wallet_rounded,
        ),
        const SizedBox(height: 10),
        _PeriodMarketTile(
          labelKey: "five_market_row_gold",
          profitPkr: summary.goldProfitPkr,
          subLabel: priceDrivenLabel,
          color: _kGoldColor,
          icon: Icons.diamond_outlined,
        ),
      ],
    );
  }
}

class _PeriodMarketTile extends StatelessWidget {
  const _PeriodMarketTile({
    required this.labelKey,
    required this.profitPkr,
    required this.subLabel,
    required this.color,
    required this.icon,
  });

  final String labelKey;
  final double profitPkr;
  final String subLabel;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profitColor = profitPkr > 0
        ? scheme.primary
        : profitPkr < 0
            ? scheme.error
            : scheme.onSurface;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(labelKey),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Text(
              "${profitPkr >= 0 ? "+" : ""}${_money.format(profitPkr)}",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: profitColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YearlyContributionBars extends StatelessWidget {
  const _YearlyContributionBars({required this.summary});

  final FiveMarketPeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final segments = <({String key, double profit, Color color})>[
      (key: "five_market_row_stock", profit: summary.stockProfitPkr, color: _kStockColor),
      (key: "five_market_row_tech", profit: summary.techProfitPkr, color: _kTechColor),
      (key: "five_market_row_debt", profit: summary.debtProfitPkr, color: _kDebtColor),
      (key: "five_market_row_money", profit: summary.moneyProfitPkr, color: _kMoneyColor),
      (key: "five_market_row_gold", profit: summary.goldProfitPkr, color: _kGoldColor),
    ];
    final absTotal = segments.fold<double>(
      0,
      (s, e) => s + e.profit.abs(),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr("profit_yearly_contribution_title"),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            for (final seg in segments) ...[
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      context.tr(seg.key),
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: absTotal > 0 ? seg.profit.abs() / absTotal : 0,
                        minHeight: 8,
                        backgroundColor:
                            scheme.outlineVariant.withValues(alpha: 0.4),
                        valueColor: AlwaysStoppedAnimation<Color>(seg.color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    absTotal > 0
                        ? "${(seg.profit.abs() / absTotal * 100).toStringAsFixed(0)}%"
                        : "0%",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _BestWorstMarkets extends StatelessWidget {
  const _BestWorstMarkets({required this.summary});

  final FiveMarketPeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = <({String key, double profit})>[
      (key: "five_market_row_stock", profit: summary.stockProfitPkr),
      (key: "five_market_row_tech", profit: summary.techProfitPkr),
      (key: "five_market_row_debt", profit: summary.debtProfitPkr),
      (key: "five_market_row_money", profit: summary.moneyProfitPkr),
      (key: "five_market_row_gold", profit: summary.goldProfitPkr),
    ];
    entries.sort((a, b) => b.profit.compareTo(a.profit));
    final best = entries.first;
    final worst = entries.last;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MarketRankChip(
          prefix: context.tr("profit_best_market"),
          labelKey: best.key,
          profitPkr: best.profit,
          background: scheme.primaryContainer,
          foreground: scheme.onPrimaryContainer,
        ),
        _MarketRankChip(
          prefix: context.tr("profit_worst_market"),
          labelKey: worst.key,
          profitPkr: worst.profit,
          background: worst.profit < 0
              ? scheme.errorContainer
              : scheme.surfaceContainerHighest,
          foreground: worst.profit < 0
              ? scheme.onErrorContainer
              : scheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _MarketRankChip extends StatelessWidget {
  const _MarketRankChip({
    required this.prefix,
    required this.labelKey,
    required this.profitPkr,
    required this.background,
    required this.foreground,
  });

  final String prefix;
  final String labelKey;
  final double profitPkr;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final sign = profitPkr >= 0 ? "+" : "";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "$prefix: ${context.tr(labelKey)} $sign${_money.format(profitPkr)}",
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AllTimeProfitRow extends StatelessWidget {
  const _AllTimeProfitRow({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.savings_outlined, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "${context.tr("profit_all_time_label")}: ${_money.format(amount)}",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

// ── Daily-only widgets (unchanged layout) ───────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.basePkr,
    required this.totalProfitPkr,
    required this.realizedProfit,
    required this.walletBalance,
  });

  final double basePkr;
  final double totalProfitPkr;
  final double realizedProfit;
  final double walletBalance;

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
            context.tr("live_profit_today_title"),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: totalProfitPkr),
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
          const SizedBox(height: 8),
          Text(
            "${context.tr("live_profit_base_label")}: ${_money.format(basePkr)}",
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr("live_profit_wallet_balance"),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    _money.format(walletBalance),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
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
        ],
      ),
    );
  }
}

class _MarketStatusRow extends StatelessWidget {
  const _MarketStatusRow({required this.live});

  final FiveMarketLiveProfitState live;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatusChip(
          label: !live.isTradingDay
              ? context.tr("live_profit_market_closed")
              : live.isMarketHours
                  ? context.tr("live_profit_market_open")
                  : context.tr("live_profit_after_hours_closed"),
          background: !live.isTradingDay || !live.isMarketHours
              ? scheme.errorContainer
              : scheme.primaryContainer,
          foreground: !live.isTradingDay || !live.isMarketHours
              ? scheme.onErrorContainer
              : scheme.onPrimaryContainer,
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ClosedDayBanner extends StatelessWidget {
  const _ClosedDayBanner({
    required this.tradingDay,
    required this.scheme,
  });

  final TradingDayResult tradingDay;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    if (tradingDay.isTradingDay) {
      return const SizedBox.shrink();
    }
    final subKey = switch (tradingDay.source) {
      TradingDaySource.forceOpen => "five_market_closed_sub_force_open",
      TradingDaySource.forceClosed => "five_market_closed_sub_force_closed",
      TradingDaySource.weekend => "five_market_closed_sub_weekend",
      TradingDaySource.holiday => "five_market_closed_sub_holiday",
      TradingDaySource.calendar => "five_market_closed_sub_calendar",
    };
    return Card(
      color: scheme.errorContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_busy_rounded, color: scheme.error, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr("five_market_closed_banner_title"),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onErrorContainer,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(subKey),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketBreakdownCard extends StatelessWidget {
  const _MarketBreakdownCard({
    required this.labelKey,
    required this.status,
    required this.allocatedPkr,
    required this.profitPkr,
    required this.changePercent,
    required this.subLabel,
    required this.annualRateLabel,
    required this.icon,
  });

  final String labelKey;
  final MarketSliceStatus status;
  final double allocatedPkr;
  final double profitPkr;
  final double? changePercent;
  final String subLabel;
  final String? annualRateLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profitColor = profitPkr > 0
        ? scheme.primary
        : profitPkr < 0
            ? scheme.error
            : scheme.onSurface;
    final profitText =
        "${profitPkr >= 0 ? "+" : ""}${_money.format(profitPkr)}";

    String? changeText;
    Color? changeColor;
    if (changePercent != null) {
      final pct = changePercent!;
      changeText = pct >= 0
          ? "+${pct.toStringAsFixed(2)}%"
          : "${pct.toStringAsFixed(2)}%";
      changeColor = pct > 0
          ? scheme.primary
          : pct < 0
              ? scheme.error
              : scheme.onSurfaceVariant;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr(labelKey),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                _SliceStatusChip(status: status, scheme: scheme),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "${context.tr("mkt_gold_allocated_pkr")}: ${_money.format(allocatedPkr)}",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  "${context.tr("mkt_todays_profit")}: ",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  profitText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: profitColor,
                      ),
                ),
                if (changeText != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    changeText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: changeColor,
                        ),
                  ),
                ],
              ],
            ),
            if (annualRateLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                annualRateLabel!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              subLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliceStatusChip extends StatelessWidget {
  const _SliceStatusChip({required this.status, required this.scheme});

  final MarketSliceStatus status;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final key = switch (status) {
      MarketSliceStatus.live => "five_market_status_live",
      MarketSliceStatus.realized => "five_market_status_realized",
      MarketSliceStatus.closed => "five_market_status_closed",
      MarketSliceStatus.nonTradingDay => "five_market_status_non_trading",
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        context.tr(key),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _TotalProfitCard extends StatelessWidget {
  const _TotalProfitCard({required this.totalProfitPkr});

  final double totalProfitPkr;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = totalProfitPkr > 0
        ? scheme.primary
        : totalProfitPkr < 0
            ? scheme.error
            : scheme.onSurface;
    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr("live_profit_total_today"),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: totalProfitPkr),
              duration: const Duration(milliseconds: 850),
              curve: Curves.easeOut,
              builder: (context, value, _) => Text(
                "${value >= 0 ? "+" : ""}${_moneyLive.format(value)}",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
