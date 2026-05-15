import "package:cloud_functions/cloud_functions.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../core/i18n/app_translations.dart";
import "../../features/investment/domain/five_market_models.dart";
import "../providers/five_market_admin_providers.dart";
import "../services/five_market_admin_service.dart";

enum _OverrideMode { none, forceClosed, forceOpen }

class AdminFiveMarketScreen extends ConsumerStatefulWidget {
  const AdminFiveMarketScreen({super.key});

  @override
  ConsumerState<AdminFiveMarketScreen> createState() =>
      _AdminFiveMarketScreenState();
}

class _AdminFiveMarketScreenState extends ConsumerState<AdminFiveMarketScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final _stock = TextEditingController();
  final _tech = TextEditingController();
  final _debtAlloc = TextEditingController();
  final _moneyAlloc = TextEditingController();
  final _gold = TextEditingController();
  final _debtRate = TextEditingController();
  final _moneyRate = TextEditingController();
  final _techBenchmark = TextEditingController();
  final _techTarget = TextEditingController();

  final _overrideReason = TextEditingController();
  DateTime _overrideDate = DateTime.now();
  _OverrideMode _overrideMode = _OverrideMode.none;

  bool _configLoaded = false;
  bool _savingConfig = false;
  bool _savingOverride = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _overrideDate = _pktDateFromString(adminTodayPktDateString());
    for (final c in [
      _stock,
      _tech,
      _debtAlloc,
      _moneyAlloc,
      _gold,
    ]) {
      c.addListener(_onAllocationFieldChanged);
    }
  }

  void _onAllocationFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [
      _stock,
      _tech,
      _debtAlloc,
      _moneyAlloc,
      _gold,
    ]) {
      c.removeListener(_onAllocationFieldChanged);
    }
    _tabs.dispose();
    _stock.dispose();
    _tech.dispose();
    _debtAlloc.dispose();
    _moneyAlloc.dispose();
    _gold.dispose();
    _debtRate.dispose();
    _moneyRate.dispose();
    _techBenchmark.dispose();
    _techTarget.dispose();
    _overrideReason.dispose();
    super.dispose();
  }

  DateTime _pktDateFromString(String yyyyMmDd) {
    final parts = yyyyMmDd.split("-");
    if (parts.length != 3) return DateTime.now();
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? DateTime.now().month;
    final d = int.tryParse(parts[2]) ?? DateTime.now().day;
    return DateTime(y, m, d);
  }

  String _formatPktDate(DateTime dt) =>
      DateFormat("yyyy-MM-dd").format(DateTime(dt.year, dt.month, dt.day));

  void _applyConfigToFields(FiveMarketConfig config) {
    if (_configLoaded) return;
    final a = config.allocations;
    final r = config.rates;
    _stock.text = a.stock.toStringAsFixed(1);
    _tech.text = a.tech.toStringAsFixed(1);
    _debtAlloc.text = a.debt.toStringAsFixed(1);
    _moneyAlloc.text = a.money.toStringAsFixed(1);
    _gold.text = a.gold.toStringAsFixed(1);
    _debtRate.text = r.debtAnnualPercent.toStringAsFixed(1);
    _moneyRate.text = r.moneyAnnualPercent.toStringAsFixed(1);
    _techBenchmark.text = r.techBenchmarkAnnualPercent.toStringAsFixed(1);
    _techTarget.text = r.techTargetAnnualPercent.toStringAsFixed(1);
    _configLoaded = true;
  }

  double? _parsePct(TextEditingController c) =>
      double.tryParse(c.text.trim());

  double _allocationSum() {
    return (_parsePct(_stock) ?? 0) +
        (_parsePct(_tech) ?? 0) +
        (_parsePct(_debtAlloc) ?? 0) +
        (_parsePct(_moneyAlloc) ?? 0) +
        (_parsePct(_gold) ?? 0);
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  Future<void> _saveConfig() async {
    final sum = _allocationSum();
    if ((sum - 100).abs() > 0.01) {
      _snack(context.tr("admin_five_market_invalid_allocation_sum"), error: true);
      return;
    }

    final debtRate = _parsePct(_debtRate);
    final moneyRate = _parsePct(_moneyRate);
    final techBench = _parsePct(_techBenchmark);
    final techTgt = _parsePct(_techTarget);
    if (debtRate == null ||
        moneyRate == null ||
        techBench == null ||
        techTgt == null) {
      _snack(context.tr("admin_five_market_invalid_rates"), error: true);
      return;
    }

    setState(() => _savingConfig = true);
    try {
      await ref.read(fiveMarketAdminServiceProvider).saveConfig(
            allocations: {
              "stock": _parsePct(_stock) ?? 0,
              "tech": _parsePct(_tech) ?? 0,
              "debt": _parsePct(_debtAlloc) ?? 0,
              "money": _parsePct(_moneyAlloc) ?? 0,
              "gold": _parsePct(_gold) ?? 0,
            },
            rates: {
              "debtAnnualPercent": debtRate,
              "moneyAnnualPercent": moneyRate,
              "techBenchmarkAnnualPercent": techBench,
              "techTargetAnnualPercent": techTgt,
            },
          );
      if (!mounted) return;
      _snack(context.tr("admin_five_market_config_saved"));
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _snack(
        "${context.tr("admin_five_market_config_save_failed")}: "
        "${fiveMarketAdminCallableErrorMessage(e)}",
        error: true,
      );
    } catch (e) {
      if (!mounted) return;
      _snack(
        "${context.tr("admin_five_market_config_save_failed")}: $e",
        error: true,
      );
    } finally {
      if (mounted) setState(() => _savingConfig = false);
    }
  }

  Future<void> _saveOverride() async {
    final reason = _overrideReason.text.trim();
    if (reason.isEmpty) {
      _snack(context.tr("admin_five_market_override_reason_required"), error: true);
      return;
    }

    final (forceClosed, forceOpen) = switch (_overrideMode) {
      _OverrideMode.none => (false, false),
      _OverrideMode.forceClosed => (true, false),
      _OverrideMode.forceOpen => (false, true),
    };

    setState(() => _savingOverride = true);
    try {
      await ref.read(fiveMarketAdminServiceProvider).saveDayOverride(
            date: _formatPktDate(_overrideDate),
            forceClosedAll: forceClosed,
            forceOpenDailyProfits: forceOpen,
            reason: reason,
          );
      if (!mounted) return;
      _snack(context.tr("admin_five_market_override_saved"));
      _overrideReason.clear();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _snack(
        "${context.tr("admin_five_market_override_save_failed")}: "
        "${fiveMarketAdminCallableErrorMessage(e)}",
        error: true,
      );
    } catch (e) {
      if (!mounted) return;
      _snack(
        "${context.tr("admin_five_market_override_save_failed")}: $e",
        error: true,
      );
    } finally {
      if (mounted) setState(() => _savingOverride = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(adminFiveMarketConfigProvider);
    configAsync.whenData(_applyConfigToFields);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr("admin_five_market_title"),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr("admin_five_market_subtitle"),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: context.tr("admin_five_market_tab_config")),
            Tab(text: context.tr("admin_five_market_tab_overrides")),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _ConfigTab(
                configAsync: configAsync,
                stock: _stock,
                tech: _tech,
                debtAlloc: _debtAlloc,
                moneyAlloc: _moneyAlloc,
                gold: _gold,
                debtRate: _debtRate,
                moneyRate: _moneyRate,
                techBenchmark: _techBenchmark,
                techTarget: _techTarget,
                allocationSum: _allocationSum,
                saving: _savingConfig,
                onSave: _saveConfig,
              ),
              _OverridesTab(
                overrideDate: _overrideDate,
                overrideMode: _overrideMode,
                reasonController: _overrideReason,
                saving: _savingOverride,
                onPickDate: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _overrideDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (picked != null) {
                    setState(() => _overrideDate = picked);
                  }
                },
                onModeChanged: (m) => setState(() => _overrideMode = m),
                onSave: _saveOverride,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfigTab extends StatelessWidget {
  const _ConfigTab({
    required this.configAsync,
    required this.stock,
    required this.tech,
    required this.debtAlloc,
    required this.moneyAlloc,
    required this.gold,
    required this.debtRate,
    required this.moneyRate,
    required this.techBenchmark,
    required this.techTarget,
    required this.allocationSum,
    required this.saving,
    required this.onSave,
  });

  final AsyncValue<FiveMarketConfig> configAsync;
  final TextEditingController stock;
  final TextEditingController tech;
  final TextEditingController debtAlloc;
  final TextEditingController moneyAlloc;
  final TextEditingController gold;
  final TextEditingController debtRate;
  final TextEditingController moneyRate;
  final TextEditingController techBenchmark;
  final TextEditingController techTarget;
  final double Function() allocationSum;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final sum = allocationSum();
    final sumOk = (sum - 100).abs() <= 0.01;

    return configAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("$e")),
      data: (_) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            context.tr("admin_five_market_allocations_title"),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _PctField(
            controller: stock,
            label: context.tr("admin_five_market_alloc_stock"),
          ),
          _PctField(
            controller: tech,
            label: context.tr("admin_five_market_alloc_tech"),
          ),
          _PctField(
            controller: debtAlloc,
            label: context.tr("admin_five_market_alloc_debt"),
          ),
          _PctField(
            controller: moneyAlloc,
            label: context.tr("admin_five_market_alloc_money"),
          ),
          _PctField(
            controller: gold,
            label: context.tr("admin_five_market_alloc_gold"),
          ),
          const SizedBox(height: 8),
          Text(
            context.trParams("admin_five_market_sum_label", {
              "sum": sum.toStringAsFixed(1),
            }),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: sumOk
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 24),
          Text(
            context.tr("admin_five_market_rates_title"),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _PctField(
            controller: debtRate,
            label: context.tr("admin_five_market_rate_debt"),
          ),
          _PctField(
            controller: moneyRate,
            label: context.tr("admin_five_market_rate_money"),
          ),
          _PctField(
            controller: techBenchmark,
            label: context.tr("admin_five_market_rate_tech_benchmark"),
          ),
          _PctField(
            controller: techTarget,
            label: context.tr("admin_five_market_rate_tech_target"),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: saving || !sumOk ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(context.tr("admin_five_market_save_config")),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverridesTab extends ConsumerWidget {
  const _OverridesTab({
    required this.overrideDate,
    required this.overrideMode,
    required this.reasonController,
    required this.saving,
    required this.onPickDate,
    required this.onModeChanged,
    required this.onSave,
  });

  final DateTime overrideDate;
  final _OverrideMode overrideMode;
  final TextEditingController reasonController;
  final bool saving;
  final VoidCallback onPickDate;
  final ValueChanged<_OverrideMode> onModeChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overridesAsync = ref.watch(adminFiveMarketDayOverridesProvider);
    final dateFmt = DateFormat.yMMMd();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          context.tr("admin_five_market_override_title"),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onPickDate,
          icon: const Icon(Icons.date_range_outlined),
          label: Text(
            "${context.tr("admin_five_market_override_date")}: ${dateFmt.format(overrideDate)}",
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<_OverrideMode>(
          segments: [
            ButtonSegment(
              value: _OverrideMode.none,
              label: Text(context.tr("admin_five_market_override_mode_none")),
            ),
            ButtonSegment(
              value: _OverrideMode.forceClosed,
              label: Text(context.tr("admin_five_market_override_mode_closed")),
            ),
            ButtonSegment(
              value: _OverrideMode.forceOpen,
              label: Text(context.tr("admin_five_market_override_mode_open")),
            ),
          ],
          selected: {overrideMode},
          onSelectionChanged: (s) => onModeChanged(s.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: reasonController,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: context.tr("admin_five_market_override_reason"),
            hintText: context.tr("admin_five_market_override_reason_hint"),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(context.tr("admin_five_market_override_save")),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          context.tr("admin_five_market_override_recent"),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        overridesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text("$e"),
          data: (items) {
            if (items.isEmpty) {
              return Text(context.tr("admin_five_market_override_empty"));
            }
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(
                        alpha: 0.2,
                      ),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final o = items[i];
                  final mode = o.forceOpenDailyProfits
                      ? context.tr("admin_five_market_override_mode_open")
                      : o.forceClosedAll
                          ? context.tr("admin_five_market_override_mode_closed")
                          : "—";
                  return ListTile(
                    title: Text(o.date),
                    subtitle: Text("$mode · ${o.reason}"),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PctField extends StatelessWidget {
  const _PctField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r"^\d*\.?\d*")),
        ],
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
          suffixText: "%",
        ),
      ),
    );
  }
}
