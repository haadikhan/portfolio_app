import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../features/investment/providers/kmi30_company_allocation_provider.dart";
import "../data/models/kmi30_tick.dart";
import "../data/websocket/psx_websocket_service.dart";
import "providers/kmi30_companies_providers.dart";
import "widgets/gold_price_card.dart";

final _pkr = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);

class Kmi30CompaniesScreen extends ConsumerWidget {
  const Kmi30CompaniesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseList = ref.watch(filteredKmi30CompaniesProvider);
    final query = ref.watch(companySearchQueryProvider);
    final ws = ref.watch(wsConnectionStatusProvider);
    final allocList = ref.watch(kmi30CompanyAllocationsProvider);
    final sortMode = ref.watch(kmi30SortModeProvider);
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
      const Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: GoldPriceCard(),
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
          ref.watch(selectedCompanyLiveTickStreamProvider(c.symbol));
      final t = liveAsync.valueOrNull ?? restAsync.valueOrNull;

      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () =>
              context.push("/market/kmi30-companies/${c.symbol}"),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.symbol,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: () {
                      if (t == null && restAsync.isLoading) {
                        return const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      if (t == null) {
                        return Text(
                          "--",
                          style: Theme.of(context).textTheme.bodySmall,
                        );
                      }
                      final last = t.price;
                      final dayPct =
                          displayKmi30Percent(t.changePercent);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${context.tr("market_last")} ${last.toStringAsFixed(2)}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            "${context.tr("market_day_change")} "
                            "${dayPct >= 0 ? "+" : ""}${dayPct.toStringAsFixed(2)}%",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: dayPct >= 0
                                  ? Colors.green.shade600
                                  : Colors.red.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    }(),
                  ),
                ),
                Flexible(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _InvestedColumn(alloc: alloc),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
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

class _InvestedColumn extends StatelessWidget {
  const _InvestedColumn({required this.alloc});

  final Kmi30CompanyAllocation? alloc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (alloc == null || !alloc!.hasInvestment) {
      return Text(
        "--",
        style: theme.textTheme.bodySmall,
        textAlign: TextAlign.end,
      );
    }
    final a = alloc!;
    final plColor = a.todayProfitPkr > 0
        ? Colors.green.shade600
        : a.todayProfitPkr < 0
            ? Colors.red.shade600
            : theme.colorScheme.onSurfaceVariant;
    final plSign = a.todayProfitPkr >= 0 ? "+" : "";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "${context.tr("kmi30_allocated_short")}\n${_pkr.format(a.investedPkr)}",
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "${context.tr("kmi30_today_pl_short")}: $plSign${_pkr.format(a.todayProfitPkr)}",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: plColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
