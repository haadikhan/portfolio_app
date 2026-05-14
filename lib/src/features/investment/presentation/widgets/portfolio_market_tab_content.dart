import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../../../core/i18n/app_translations.dart";
import "../../../../models/portfolio_model.dart";
import "../../data/allocation_money_market.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);
final _pctFmt = NumberFormat("#0.#");

enum PortfolioMarketCategory {
  digitalGold,
  money,
  stock,
  tech,
  debt,
}

double sleeveAmountForCategory(double total, PortfolioMarketCategory category) {
  switch (category) {
    case PortfolioMarketCategory.digitalGold:
      return digitalGoldSleeveAmountFromTotal(total);
    case PortfolioMarketCategory.money:
      return moneyMarketAmountFromAllocationTotal(total);
    case PortfolioMarketCategory.stock:
      return stockSleeveAmountFromTotal(total);
    case PortfolioMarketCategory.tech:
      return techSleeveAmountFromTotal(total);
    case PortfolioMarketCategory.debt:
      return debtSleeveAmountFromTotal(total);
  }
}

double targetPercentForCategory(PortfolioMarketCategory category) {
  switch (category) {
    case PortfolioMarketCategory.digitalGold:
      return kAlternativeAssetAllocationPercent;
    case PortfolioMarketCategory.money:
      return kMoneyMarketAllocationPercent;
    case PortfolioMarketCategory.stock:
      return kStockMarketAllocationPercent;
    case PortfolioMarketCategory.tech:
      return kTechAllocationPercent;
    case PortfolioMarketCategory.debt:
      return kDebtMarketAllocationPercent;
  }
}

Color _accentFor(PortfolioMarketCategory category) {
  return switch (category) {
    PortfolioMarketCategory.digitalGold => const Color(0xFFD4AF37),
    PortfolioMarketCategory.money => const Color(0xFF9C27B0),
    PortfolioMarketCategory.stock => const Color(0xFF0F7A2C),
    PortfolioMarketCategory.tech => const Color(0xFF2196F3),
    PortfolioMarketCategory.debt => const Color(0xFFFF9800),
  };
}

IconData _watermarkIcon(PortfolioMarketCategory category) {
  return switch (category) {
    PortfolioMarketCategory.digitalGold => Icons.layers_rounded,
    PortfolioMarketCategory.money => Icons.description_rounded,
    PortfolioMarketCategory.stock => Icons.candlestick_chart_rounded,
    PortfolioMarketCategory.tech => Icons.auto_awesome_rounded,
    PortfolioMarketCategory.debt => Icons.account_balance_rounded,
  };
}

String _tabTitleKey(PortfolioMarketCategory category) {
  return switch (category) {
    PortfolioMarketCategory.digitalGold => "portfolio_tab_digital_gold_title",
    PortfolioMarketCategory.money => "portfolio_tab_money_title",
    PortfolioMarketCategory.stock => "portfolio_tab_stock_title",
    PortfolioMarketCategory.tech => "portfolio_tab_tech_title",
    PortfolioMarketCategory.debt => "portfolio_tab_debt_title",
  };
}

String _introKey(PortfolioMarketCategory category) {
  return switch (category) {
    PortfolioMarketCategory.digitalGold => "portfolio_tab_digital_gold_intro",
    PortfolioMarketCategory.money => "portfolio_tab_money_intro",
    PortfolioMarketCategory.stock => "portfolio_tab_stock_intro",
    PortfolioMarketCategory.tech => "portfolio_tab_tech_intro",
    PortfolioMarketCategory.debt => "portfolio_tab_debt_intro",
  };
}

List<String> _detailKeys(PortfolioMarketCategory category) {
  return switch (category) {
    PortfolioMarketCategory.digitalGold => [
        "portfolio_tab_digital_gold_detail_1",
        "portfolio_tab_digital_gold_detail_2",
        "portfolio_tab_digital_gold_detail_3",
      ],
    PortfolioMarketCategory.money => [
        "portfolio_tab_money_detail_1",
        "portfolio_tab_money_detail_2",
        "portfolio_tab_money_detail_3",
      ],
    PortfolioMarketCategory.stock => [
        "portfolio_tab_stock_detail_1",
        "portfolio_tab_stock_detail_2",
        "portfolio_tab_stock_detail_3",
      ],
    PortfolioMarketCategory.tech => [
        "portfolio_tab_tech_detail_1",
        "portfolio_tab_tech_detail_2",
        "portfolio_tab_tech_detail_3",
      ],
    PortfolioMarketCategory.debt => [
        "portfolio_tab_debt_detail_1",
        "portfolio_tab_debt_detail_2",
        "portfolio_tab_debt_detail_3",
      ],
  };
}

/// Tab body for one illustrative market sleeve on My Portfolio.
class PortfolioMarketTabPage extends StatelessWidget {
  const PortfolioMarketTabPage({
    super.key,
    required this.category,
    required this.totalAllocationPkr,
    this.portfolio,
  });

  final PortfolioMarketCategory category;
  final double totalAllocationPkr;
  final PortfolioModel? portfolio;

  String _formatSleeve(double v) {
    if (!v.isFinite || v <= 0) return _money.format(0);
    return _money.format(v);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _accentFor(category);
    final pct = targetPercentForCategory(category);
    final sleeve = sleeveAmountForCategory(totalAllocationPkr, category);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              height: 118,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color.lerp(accent, Colors.black, 0.42)!,
                          Color.lerp(accent, Colors.black, 0.62)!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.85, -0.35),
                        radius: 1.15,
                        colors: [
                          Colors.white.withValues(alpha: 0.14),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -28,
                    bottom: -28,
                    child: Icon(
                      _watermarkIcon(category),
                      size: 132,
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                context.tr(_tabTitleKey(category)),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                            if (category == PortfolioMarketCategory.debt)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  borderRadius: BorderRadius.circular(999),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    child: Text(
                                      context.tr("portfolio_debt_ijara_badge"),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: context.tr("portfolio_tab_target_pct"),
                  value: "${_pctFmt.format(pct)}%",
                  accent: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: context.tr("portfolio_tab_sleeve_pkr"),
                  value: _formatSleeve(sleeve),
                  accent: accent,
                ),
              ),
            ],
          ),
          if (portfolio != null) ...[
            const SizedBox(height: 12),
            Text(
              "${context.tr("last_updated")}: "
              "${DateFormat("dd MMM yyyy, HH:mm").format(portfolio!.lastUpdated)}",
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _DetailCard(
            icon: Icons.topic_rounded,
            body: context.tr(_introKey(category)),
          ),
          ..._detailKeys(category).map(
            (key) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _DetailCard(
                icon: Icons.arrow_outward_rounded,
                body: context.tr(key),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.tr("portfolio_tab_mix_footer"),
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
        gradient: LinearGradient(
          colors: [
            scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            scheme.surface.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.icon, required this.body});

  final IconData icon;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              body,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
