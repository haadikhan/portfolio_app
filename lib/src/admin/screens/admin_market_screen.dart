import "package:cloud_functions/cloud_functions.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../core/i18n/app_translations.dart";
import "../../models/market_daily_bar.dart";
import "../../providers/market_providers.dart";
import "../providers/admin_market_providers.dart";

class AdminMarketScreen extends ConsumerStatefulWidget {
  const AdminMarketScreen({super.key});

  @override
  ConsumerState<AdminMarketScreen> createState() => _AdminMarketScreenState();
}

class _AdminMarketScreenState extends ConsumerState<AdminMarketScreen> {
  final _name = TextEditingController();
  final _ticker = TextEditingController();
  final _exchange = TextEditingController(text: "PSX");
  bool _active = true;
  bool _savingCompany = false;

  DateTime _barDate = DateTime.now();
  final _open = TextEditingController();
  final _close = TextEditingController();
  final _high = TextEditingController();
  final _low = TextEditingController();
  bool _savingBar = false;
  bool _syncing = false;

  @override
  void dispose() {
    _name.dispose();
    _ticker.dispose();
    _exchange.dispose();
    _open.dispose();
    _close.dispose();
    _high.dispose();
    _low.dispose();
    super.dispose();
  }

  Future<void> _saveCompany() async {
    final actor = ref.read(adminActorUidProvider);
    if (actor == null) return;
    final name = _name.text.trim();
    final ticker = _ticker.text.trim();
    if (name.isEmpty || ticker.isEmpty) return;

    setState(() => _savingCompany = true);
    try {
      await ref.read(marketDataServiceProvider).upsertCompany(
            name: name,
            ticker: ticker,
            exchange: _exchange.text.trim(),
            isActive: _active,
            actorUid: actor,
          );
      _name.clear();
      _ticker.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("market_company_saved"))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${context.tr("error_prefix")} $e")),
      );
    } finally {
      if (mounted) setState(() => _savingCompany = false);
    }
  }

  Future<void> _saveBar() async {
    final selected = ref.read(adminSelectedCompanyProvider);
    if (selected == null) return;
    final actor = ref.read(adminActorUidProvider);
    final open = double.tryParse(_open.text.trim());
    final close = double.tryParse(_close.text.trim());
    if (open == null || close == null) return;
    final high = double.tryParse(_high.text.trim());
    final low = double.tryParse(_low.text.trim());

    setState(() => _savingBar = true);
    try {
      await ref.read(marketDataServiceProvider).upsertDailyBar(
            companyId: selected.id,
            date: DateTime(_barDate.year, _barDate.month, _barDate.day),
            open: open,
            close: close,
            high: high,
            low: low,
            source: "manual",
            updatedBy: actor,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("market_day_saved"))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${context.tr("error_prefix")} $e")),
      );
    } finally {
      if (mounted) setState(() => _savingBar = false);
    }
  }

  Future<void> _syncFromApi() async {
    final selected = ref.read(adminSelectedCompanyProvider);
    if (selected == null) return;
    setState(() => _syncing = true);
    try {
      final result = await ref
          .read(marketFunctionsProvider)
          .httpsCallable("syncMarketDailyBars")
          .call({"companyId": selected.id});
      if (!mounted) return;
      final payload = Map<String, dynamic>.from(result.data as Map);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${context.tr("market_sync_ok")} (${payload["written"] ?? 0})",
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${context.tr("market_sync_failed")}: ${e.message}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${context.tr("market_sync_failed")}: $e")),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final companiesAsync = ref.watch(adminMarketCompaniesProvider);
    final selected = ref.watch(adminSelectedCompanyProvider);
    final barsAsync = ref.watch(adminSelectedCompanyBarsProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          context.tr("admin_market_title"),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Text(context.tr("admin_market_subtitle")),
        const SizedBox(height: 16),
        _Section(
          title: context.tr("market_add_company"),
          child: Column(
            children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: context.tr("market_company_name"),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ticker,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: context.tr("market_ticker"),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _exchange,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: context.tr("market_exchange"),
                      ),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: Text(context.tr("market_active")),
                contentPadding: EdgeInsets.zero,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _savingCompany ? null : _saveCompany,
                  child: Text(context.tr("save_btn")),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: context.tr("market_daily_entry"),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              companiesAsync.when(
                data: (companies) {
                  if (companies.isEmpty) return Text(context.tr("market_no_companies"));
                  final current = selected?.id ?? companies.first.id;
                  return DropdownButtonFormField<String>(
                    initialValue: current,
                    decoration: InputDecoration(
                      labelText: context.tr("market_company"),
                      border: const OutlineInputBorder(),
                    ),
                    items: companies
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text("${c.name} (${c.ticker})"),
                            ))
                        .toList(),
                    onChanged: (v) => ref.read(adminSelectedCompanyIdProvider.notifier).state = v,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text("${context.tr("error_prefix")} $e"),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDate: _barDate,
                        );
                        if (picked != null) setState(() => _barDate = picked);
                      },
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text(DateFormat.yMMMd().format(_barDate)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _syncing ? null : _syncFromApi,
                      icon: const Icon(Icons.sync_outlined),
                      label: Text(context.tr("market_sync_api")),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _open,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: context.tr("market_open"),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _close,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: context.tr("market_close"),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _high,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: context.tr("market_high_optional"),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _low,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: context.tr("market_low_optional"),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _savingBar ? null : _saveBar,
                  child: Text(context.tr("market_save_day")),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: context.tr("market_recent_days"),
          child: barsAsync.when(
            data: (bars) => _RecentBarsList(bars: bars),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text("${context.tr("error_prefix")} $e"),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RecentBarsList extends StatelessWidget {
  const _RecentBarsList({required this.bars});
  final List<MarketDailyBar> bars;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return Text(context.tr("market_no_data"));
    }
    final recent = bars.reversed.take(12).toList();
    return DataTable(
      columns: [
        DataColumn(label: Text(context.tr("market_date"))),
        DataColumn(label: Text(context.tr("market_open"))),
        DataColumn(label: Text(context.tr("market_close"))),
        DataColumn(label: Text(context.tr("market_source"))),
      ],
      rows: recent
          .map(
            (b) => DataRow(
              cells: [
                DataCell(Text(DateFormat.yMd().format(b.date))),
                DataCell(Text(b.open.toStringAsFixed(2))),
                DataCell(Text(b.close.toStringAsFixed(2))),
                DataCell(Text(b.source)),
              ],
            ),
          )
          .toList(),
    );
  }
}
