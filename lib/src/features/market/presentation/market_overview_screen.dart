import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../providers/market_providers.dart";
import "widgets/market_close_chart.dart";

class MarketOverviewScreen extends ConsumerWidget {
  const MarketOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companiesAsync = ref.watch(marketCompaniesProvider);
    final selected = ref.watch(selectedMarketCompanyProvider);
    final barsAsync = ref.watch(marketDailyBarsProvider);
    final money = NumberFormat.decimalPatternDigits(decimalDigits: 2);

    return AppScaffold(
      title: context.tr("market_title"),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(marketCompaniesProvider);
          ref.invalidate(marketDailyBarsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            companiesAsync.when(
              data: (companies) {
                if (companies.isEmpty) {
                  return Text(context.tr("market_no_companies"));
                }
                final currentId = selected?.id ?? companies.first.id;
                return DropdownButtonFormField<String>(
                  initialValue: currentId,
                  decoration: InputDecoration(
                    labelText: context.tr("market_company"),
                    border: const OutlineInputBorder(),
                  ),
                  items: companies
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text("${c.name} (${c.ticker})"),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => ref.read(selectedMarketCompanyIdProvider.notifier).state = v,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text("${context.tr("error_prefix")} $e"),
            ),
            const SizedBox(height: 16),
            barsAsync.when(
              data: (bars) {
                if (bars.isEmpty) {
                  return Text(context.tr("market_no_data"));
                }
                final latest = bars.last;
                final prev = bars.length > 1 ? bars[bars.length - 2] : null;
                final diff = prev == null ? null : latest.close - prev.close;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MetricCard(
                      title: context.tr("market_latest_day"),
                      subtitle: DateFormat.yMMMd().format(latest.date),
                      open: latest.open,
                      close: latest.close,
                      openLabel: context.tr("market_open"),
                      closeLabel: context.tr("market_close"),
                      source: latest.source,
                      sourceLabel: context.tr("market_source"),
                      money: money,
                      delta: diff,
                    ),
                    const SizedBox(height: 14),
                    MarketCloseChart(bars: bars),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text("${context.tr("error_prefix")} $e"),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr("market_delay_disclaimer"),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.subtitle,
    required this.open,
    required this.close,
    required this.openLabel,
    required this.closeLabel,
    required this.source,
    required this.sourceLabel,
    required this.money,
    required this.delta,
  });

  final String title;
  final String subtitle;
  final double open;
  final double close;
  final String openLabel;
  final String closeLabel;
  final String source;
  final String sourceLabel;
  final NumberFormat money;
  final double? delta;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text("$openLabel: ${money.format(open)}")),
              Expanded(child: Text("$closeLabel: ${money.format(close)}")),
            ],
          ),
          const SizedBox(height: 8),
          if (delta != null)
            Text(
              "Δ ${money.format(delta)}",
              style: TextStyle(
                color: delta! >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 4),
          Text("$sourceLabel: $source"),
        ],
      ),
    );
  }
}
