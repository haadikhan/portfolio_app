import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../data/models/kmi30_tick.dart";
import "../data/websocket/psx_websocket_service.dart";
import "providers/kmi30_companies_providers.dart";
import "widgets/gold_price_card.dart";

class Kmi30CompaniesScreen extends ConsumerWidget {
  const Kmi30CompaniesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companies = ref.watch(filteredKmi30CompaniesProvider);
    final query = ref.watch(companySearchQueryProvider);
    final ws = ref.watch(wsConnectionStatusProvider);

    return AppScaffold(
      title: context.tr("kmi30_companies_title"),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: GoldPriceCard(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) =>
                  ref.read(companySearchQueryProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: context.tr("kmi30_search_hint"),
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          ref.read(companySearchQueryProvider.notifier).state =
                              "";
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _WsDot(
                    connected: ws.valueOrNull == PsxWsStatus.connected,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr("market_ws_live_disclaimer"),
                    maxLines: 4,
                    softWrap: true,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.read(goldPriceRefreshCounterProvider.notifier).refresh();
              },
              child: companies.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: 260,
                          child: Center(
                            child: Text(context.tr("kmi30_no_companies")),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: companies.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final c = companies[i];
                        final restAsync = ref.watch(
                          kmi30RestTickProvider(c.symbol),
                        );
                        final liveAsync = ref.watch(
                          selectedCompanyLiveTickStreamProvider(c.symbol),
                        );
                        final t =
                            liveAsync.valueOrNull ?? restAsync.valueOrNull;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context.push(
                            "/market/kmi30-companies/${c.symbol}",
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.symbol,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
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
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        );
                                      }
                                      if (t == null) {
                                        return Text(
                                          "--",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        );
                                      }
                                      final last = t.price;
                                      final dayPct = displayKmi30Percent(
                                        t.changePercent,
                                      );
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
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
                                            "${context.tr("market_day_change")} ${dayPct >= 0 ? "+" : ""}${dayPct.toStringAsFixed(2)}%",
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
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
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
