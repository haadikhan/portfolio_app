import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../features/investment/domain/five_market_models.dart";
import "../../../features/investment/providers/five_market_providers.dart";
import "../../../features/investment/providers/kmi30_company_allocation_provider.dart";
import "../data/models/kmi30_tick.dart";
import "../data/websocket/psx_websocket_service.dart";
import "providers/kmi30_companies_providers.dart";
import "widgets/gold_price_card.dart";

final _pkr = NumberFormat("#,##0");

class Kmi30CompaniesScreen extends ConsumerWidget {
  const Kmi30CompaniesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseList = ref.watch(filteredKmi30CompaniesProvider);
    final query = ref.watch(companySearchQueryProvider);
    final ws = ref.watch(wsConnectionStatusProvider);
    final allocList = ref.watch(kmi30CompanyAllocationsProvider);
    final sortMode = ref.watch(kmi30SortModeProvider);
    final tradingDay = ref.watch(todayTradingDayProvider);
    final isTradingDay = tradingDay.isTradingDay;
    final allocBySymbol = {
      for (final a in allocList) a.symbol: a,
    };

    final companies = List.of(baseList);
    switch (sortMode) {
      case Kmi30SortMode.original:
        break;
      case Kmi30SortMode.gainFirst:
        companies.sort((a, b) {
          final pa = allocBySymbol[a.symbol]?.todayProfitPkr ?? 0;
          final pb = allocBySymbol[b.symbol]?.todayProfitPkr ?? 0;
          return pb.compareTo(pa);
        });
      case Kmi30SortMode.lossFirst:
        companies.sort((a, b) {
          final pa = allocBySymbol[a.symbol]?.todayProfitPkr ?? 0;
          final pb = allocBySymbol[b.symbol]?.todayProfitPkr ?? 0;
          return pa.compareTo(pb);
        });
    }

    // Header slivers rendered as leading items in a single scrollable list
    final headerItems = <Widget>[
      if (!isTradingDay) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: _OffDayBanner(tradingDay: tradingDay),
        ),
        const SizedBox(height: 8),
      ],
      Padding(
        padding: EdgeInsets.fromLTRB(12, isTradingDay ? 12 : 0, 12, 8),
        child: _Kmi30HeroHeader(isTradingDay: isTradingDay),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: SizedBox(
          height: 36,
          child: TextField(
            onChanged: (v) =>
                ref.read(companySearchQueryProvider.notifier).state = v,
            style: Theme.of(context).textTheme.bodySmall,
            decoration: InputDecoration(
              hintText: context.tr("kmi30_search_hint"),
              hintStyle: Theme.of(context).textTheme.bodySmall,
              prefixIcon: const Icon(Icons.search, size: 18),
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      iconSize: 16,
                      onPressed: () {
                        ref
                            .read(companySearchQueryProvider.notifier)
                            .state = "";
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
        ),
      ),
      // Sort chips — single compact row
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Row(
          children: [
            _SortChip(
              label: context.tr("kmi30_sort_original"),
              selected: sortMode == Kmi30SortMode.original,
              onTap: () => ref.read(kmi30SortModeProvider.notifier).state =
                  Kmi30SortMode.original,
            ),
            const SizedBox(width: 6),
            _SortChip(
              label: context.tr("kmi30_sort_best"),
              selected: sortMode == Kmi30SortMode.gainFirst,
              onTap: () => ref.read(kmi30SortModeProvider.notifier).state =
                  Kmi30SortMode.gainFirst,
            ),
            const SizedBox(width: 6),
            _SortChip(
              label: context.tr("kmi30_sort_worst"),
              selected: sortMode == Kmi30SortMode.lossFirst,
              onTap: () => ref.read(kmi30SortModeProvider.notifier).state =
                  Kmi30SortMode.lossFirst,
            ),
          ],
        ),
      ),
      // WS status row
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _WsDot(
                connected: ws.valueOrNull == PsxWsStatus.connected,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr("market_ws_live_disclaimer"),
                    maxLines: 3,
                    softWrap: true,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (ws.valueOrNull == PsxWsStatus.disconnected) ...[
                    const SizedBox(height: 2),
                    Text(
                      "Live stream unavailable. Showing latest snapshot data.",
                      maxLines: 2,
                      softWrap: true,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ];

    final emptyBody = <Widget>[
      SizedBox(
        height: 260,
        child: Center(child: Text(context.tr("kmi30_no_companies"))),
      ),
    ];

    final companyItems = companies.map<Widget>((c) {
      final alloc = allocBySymbol[c.symbol];
      final restAsync = ref.watch(kmi30RestTickProvider(c.symbol));
      final liveAsync =
          ref.watch(ahleTradeTickStreamProvider(c.symbol));
      final t = selectKmi30CompanyTick(
        liveAsync.valueOrNull,
        restAsync.valueOrNull,
      );
      final theme = Theme.of(context);
      final dayPct =
          t != null ? displayKmi30Percent(t.changePercent) : 0.0;
      final hasInvest = alloc != null && alloc.hasInvestment;

      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            context.push("/market/kmi30-companies/${c.symbol}"),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── ROW 1: Identity + Price ──────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.symbol,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (t == null)
                        Text("--", style: theme.textTheme.bodyMedium)
                      else
                        Text(
                          "PKR ${t.price.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (t != null && isTradingDay)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: dayPct >= 0
                                ? Colors.green.shade600
                                    .withValues(alpha: 0.12)
                                : Colors.red.shade600
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "${dayPct >= 0 ? "+" : ""}${dayPct.toStringAsFixed(2)}%",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: dayPct >= 0
                                  ? Colors.green.shade600
                                  : Colors.red.shade600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 10),
              // ── ROW 2: Investment metrics ────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Allocated",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasInvest
                              ? "PKR ${_pkr.format(alloc.investedPkr)}"
                              : "--",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Index weight",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasInvest
                              ? "${alloc.weightPercent.toStringAsFixed(1)}%"
                              : "--",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Today P&L",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          !hasInvest || !isTradingDay
                              ? "--"
                              : "${alloc.todayProfitPkr >= 0 ? "+" : ""}PKR "
                                  "${_pkr.format(alloc.todayProfitPkr)}",
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: !hasInvest || !isTradingDay
                                ? theme.colorScheme.onSurfaceVariant
                                : alloc.todayProfitPkr > 0
                                    ? Colors.green.shade600
                                    : alloc.todayProfitPkr < 0
                                        ? Colors.red.shade600
                                        : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();

    return AppScaffold(
      title: context.tr("kmi30_companies_title"),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(goldPriceRefreshCounterProvider.notifier).refresh();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
          children: [
            ...headerItems,
            if (companies.isEmpty)
              ...emptyBody
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(children: companyItems),
              ),
          ],
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
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
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected
                    ? scheme.onPrimary
                    : scheme.onSurfaceVariant,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

class _Kmi30HeroHeader extends StatelessWidget {
  const _Kmi30HeroHeader({required this.isTradingDay});

  final bool isTradingDay;

  @override
  Widget build(BuildContext context) {
    if (isTradingDay) {
      return const GoldPriceCard();
    }

    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            const GoldPriceCard(),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: constraints.maxWidth / 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.92),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(16),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.show_chart_rounded,
                              size: 16,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "KMI-30",
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        context.tr("kmi30_market_closed_today"),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr("kmi30_day_change_off_day"),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OffDayBanner extends StatelessWidget {
  const _OffDayBanner({required this.tradingDay});

  final TradingDayResult tradingDay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subKey = switch (tradingDay.source) {
      TradingDaySource.forceOpen => "five_market_closed_sub_force_open",
      TradingDaySource.forceClosed => "five_market_closed_sub_force_closed",
      TradingDaySource.weekend => "five_market_closed_sub_weekend",
      TradingDaySource.holiday => "five_market_closed_sub_holiday",
      TradingDaySource.calendar => "kmi30_off_day_banner_sub",
    };

    return Card(
      color: scheme.errorContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.event_busy_rounded, color: scheme.error, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr("kmi30_off_day_banner_title"),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onErrorContainer,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(subKey),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
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

class _WsDot extends StatelessWidget {
  const _WsDot({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: connected ? Colors.green : Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }
}
