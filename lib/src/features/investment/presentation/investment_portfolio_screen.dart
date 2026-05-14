import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../models/portfolio_model.dart";
import "../../../providers/portfolio_providers.dart";
import "../../../providers/wallet_providers.dart";
import "../data/allocation_money_market.dart";
import "widgets/allocation_pie_chart_widget.dart";
import "widgets/performance_metrics_widget.dart";
import "widgets/portfolio_market_tab_content.dart";
import "widgets/return_history_list_widget.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);
final _dateFmt = DateFormat("dd MMM yyyy, HH:mm");

class InvestmentPortfolioScreen extends ConsumerStatefulWidget {
  const InvestmentPortfolioScreen({super.key});

  @override
  ConsumerState<InvestmentPortfolioScreen> createState() =>
      _InvestmentPortfolioScreenState();
}

class _InvestmentPortfolioScreenState
    extends ConsumerState<InvestmentPortfolioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _marketTabController;

  @override
  void initState() {
    super.initState();
    _marketTabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _marketTabController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    ref.invalidate(myPortfolioProvider);
    ref.invalidate(myReturnHistoryProvider);
    ref.invalidate(userWalletStreamProvider);
  }

  @override
  Widget build(BuildContext context) {
    final portfolioAsync = ref.watch(myPortfolioProvider);
    final historyAsync = ref.watch(myReturnHistoryProvider);
    final walletAsync = ref.watch(userWalletStreamProvider);
    final double availableBalance = walletAsync.maybeWhen(
      data: (wallet) => _readAvailableBalance(wallet),
      orElse: () => 0.0,
    );

    return AppScaffold(
      title: context.tr("my_portfolio_title"),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Section 1: Allocation ──────────────────────────────────
              _SectionHeader(label: context.tr("asset_allocation")),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final scheme = Theme.of(context).colorScheme;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scheme.surface,
                          scheme.surfaceContainerHighest.withValues(alpha: 0.25),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: scheme.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: AllocationPieChartWidget(
                      totalAmountPkr: availableBalance,
                    ),
                  );
                },
              ),

              // ── Section 2 & 3: Portfolio value + Metrics ───────────────
              const SizedBox(height: 24),
              portfolioAsync.when(
                loading: () => const _PortfolioSkeleton(),
                error: (e, _) => _ErrorCard(message: e.toString()),
                data: (portfolio) {
                  if (portfolio == null) {
                    return const _SetupPlaceholder();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PortfolioValueCard(portfolio: portfolio),
                      const SizedBox(height: 24),
                      _SectionHeader(label: context.tr("performance")),
                      const SizedBox(height: 12),
                      PerformanceMetricsWidget(portfolio: portfolio),
                      const SizedBox(height: 28),
                      _SectionHeader(
                        label: context.tr("portfolio_markets_section"),
                      ),
                      const SizedBox(height: 10),
                      _PortfolioMarketTabsPanel(
                        controller: _marketTabController,
                        totalAllocationPkr: availableBalance,
                        portfolio: portfolio,
                      ),
                    ],
                  );
                },
              ),

              // ── Section 4: Return history ──────────────────────────────
              const SizedBox(height: 24),
              _SectionHeader(label: context.tr("return_history")),
              const SizedBox(height: 12),
              historyAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => _ErrorCard(message: e.toString()),
                data: (history) => ReturnHistoryListWidget(history: history),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bounded-height tab region for illustrative sleeve detail (nested scroll).
class _PortfolioMarketTabsPanel extends StatelessWidget {
  const _PortfolioMarketTabsPanel({
    required this.controller,
    required this.totalAllocationPkr,
    required this.portfolio,
  });

  final TabController controller;
  final double totalAllocationPkr;
  final PortfolioModel portfolio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenH = MediaQuery.sizeOf(context).height;
    final panelHeight = (screenH * 0.56).clamp(400.0, 620.0);

    Widget tabLabel(String key) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            context.tr(key),
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
          ),
        );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
      ),
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: SizedBox(
        height: panelHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              controller: controller,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerHeight: 0,
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              indicatorSize: TabBarIndicatorSize.label,
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(color: scheme.primary, width: 2.5),
                borderRadius: BorderRadius.circular(99),
              ),
              labelColor: scheme.primary,
              unselectedLabelColor: scheme.onSurfaceVariant,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(child: tabLabel("portfolio_tab_digital_gold")),
                Tab(child: tabLabel("portfolio_tab_money")),
                Tab(child: tabLabel("portfolio_tab_stock")),
                Tab(child: tabLabel("portfolio_tab_tech")),
                Tab(child: tabLabel("portfolio_tab_debt")),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: controller,
                children: [
                  PortfolioMarketTabPage(
                    category: PortfolioMarketCategory.digitalGold,
                    totalAllocationPkr: totalAllocationPkr,
                    portfolio: portfolio,
                  ),
                  PortfolioMarketTabPage(
                    category: PortfolioMarketCategory.money,
                    totalAllocationPkr: totalAllocationPkr,
                    portfolio: portfolio,
                  ),
                  PortfolioMarketTabPage(
                    category: PortfolioMarketCategory.stock,
                    totalAllocationPkr: totalAllocationPkr,
                    portfolio: portfolio,
                  ),
                  PortfolioMarketTabPage(
                    category: PortfolioMarketCategory.tech,
                    totalAllocationPkr: totalAllocationPkr,
                    portfolio: portfolio,
                  ),
                  PortfolioMarketTabPage(
                    category: PortfolioMarketCategory.debt,
                    totalAllocationPkr: totalAllocationPkr,
                    portfolio: portfolio,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _readAvailableBalance(Map<String, dynamic>? wallet) {
  return allocationTotalFromWallet(wallet);
}

// ── Portfolio value hero card ────────────────────────────────────────────────

class _PortfolioValueCard extends StatelessWidget {
  const _PortfolioValueCard({required this.portfolio});
  final PortfolioModel portfolio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr("current_portfolio_value"),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            _money.format(portfolio.currentValue),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr("total_invested"),
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _money.format(portfolio.totalDeposited),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    context.tr("last_updated"),
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dateFmt.format(portfolio.lastUpdated),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
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

// ── Setup placeholder ────────────────────────────────────────────────────────

class _SetupPlaceholder extends StatelessWidget {
  const _SetupPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.hourglass_top_rounded,
              size: 40, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            context.tr("portfolio_setup_title"),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr("portfolio_setup_body"),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: scheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _PortfolioSkeleton extends StatelessWidget {
  const _PortfolioSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: TextStyle(color: scheme.error, fontSize: 12),
      ),
    );
  }
}
