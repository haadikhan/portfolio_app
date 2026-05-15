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
    _tabs = TabController(length: 4, vsync: this);
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
          isScrollable: true,
          tabs: [
            Tab(text: context.tr("admin_five_market_tab_config")),
            Tab(text: context.tr("admin_five_market_tab_overrides")),
            Tab(text: context.tr("admin_five_market_tab_holidays")),
            Tab(text: context.tr("admin_five_market_tab_eod")),
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
              const _HolidaysTab(),
              const _EodDiagnosticsTab(),
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

class _HolidaysTab extends ConsumerStatefulWidget {
  const _HolidaysTab();

  @override
  ConsumerState<_HolidaysTab> createState() => _HolidaysTabState();
}

class _HolidaysTabState extends ConsumerState<_HolidaysTab> {
  final _nameController = TextEditingController();
  DateTime _pickedDate = DateTime.now();
  bool _isIslamic = false;
  bool _estimated = false;
  String? _editingDate;
  bool _saving = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _pickedDate = _pktFromString(adminTodayPktDateString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  DateTime _pktFromString(String yyyyMmDd) {
    final parts = yyyyMmDd.split("-");
    if (parts.length != 3) return DateTime.now();
    return DateTime(
      int.tryParse(parts[0]) ?? DateTime.now().year,
      int.tryParse(parts[1]) ?? DateTime.now().month,
      int.tryParse(parts[2]) ?? DateTime.now().day,
    );
  }

  String _formatPktDate(DateTime dt) =>
      DateFormat("yyyy-MM-dd").format(DateTime(dt.year, dt.month, dt.day));

  void _clearForm() {
    _nameController.clear();
    _isIslamic = false;
    _estimated = false;
    _editingDate = null;
    _formError = null;
    _pickedDate = _pktFromString(adminTodayPktDateString());
  }

  void _loadIntoForm(PkHoliday h) {
    setState(() {
      _editingDate = h.date;
      _pickedDate = _pktFromString(h.date);
      _nameController.text = h.name;
      _isIslamic = h.isIslamicHoliday;
      _estimated = h.estimatedDate;
      _formError = null;
    });
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

  Future<void> _persist(List<PkHoliday> holidays) async {
    setState(() => _saving = true);
    try {
      await ref.read(fiveMarketAdminServiceProvider).saveHolidays(
            holidays: holidays,
          );
      if (!mounted) return;
      _snack(context.tr("admin_five_market_holidays_saved"));
      _clearForm();
    } catch (e) {
      if (!mounted) return;
      _snack(
        "${context.tr("admin_five_market_holidays_save_failed")}: $e",
        error: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addOrUpdate(List<PkHoliday> current) async {
    final dateStr = _formatPktDate(_pickedDate);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = context.tr("admin_five_market_holidays_name"));
      return;
    }
    final duplicate = current.any(
      (h) => h.date == dateStr && h.date != _editingDate,
    );
    if (duplicate) {
      setState(
        () => _formError = context.tr("admin_five_market_holidays_duplicate_date"),
      );
      return;
    }

    final next = [
      for (final h in current)
        if (h.date != dateStr && h.date != _editingDate) h,
      PkHoliday(
        date: dateStr,
        name: name,
        isIslamicHoliday: _isIslamic,
        estimatedDate: _estimated,
      ),
    ]..sort((a, b) => a.date.compareTo(b.date));

    await _persist(next);
  }

  Future<void> _deleteHoliday(PkHoliday h, List<PkHoliday> current) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr("admin_five_market_holidays_delete_title")),
        content: Text(
          context.trParams("admin_five_market_holidays_delete_body", {
            "name": h.name,
            "date": h.date,
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr("cancel")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr("admin_five_market_holidays_delete_title")),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final next = current.where((x) => x.date != h.date).toList();
    await _persist(next);
  }

  @override
  Widget build(BuildContext context) {
    final holidaysAsync = ref.watch(adminPkHolidaysProvider);
    final dateFmt = DateFormat.yMMMd();

    return holidaysAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("$e")),
      data: (holidays) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            context.tr("admin_five_market_holidays_title"),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            context.tr("admin_five_market_holidays_subtitle"),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (holidays.isEmpty)
            Text(context.tr("admin_five_market_holidays_empty"))
          else
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(
                        alpha: 0.2,
                      ),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text("Date")),
                    DataColumn(label: Text("Name")),
                    DataColumn(label: Text("Islamic")),
                    DataColumn(label: Text("Est.")),
                    DataColumn(label: Text("")),
                  ],
                  rows: [
                    for (final h in holidays)
                      DataRow(
                        onSelectChanged: (_) => _loadIntoForm(h),
                        cells: [
                          DataCell(Text(h.date)),
                          DataCell(Text(h.name)),
                          DataCell(
                            Icon(
                              h.isIslamicHoliday
                                  ? Icons.check
                                  : Icons.close,
                              size: 18,
                            ),
                          ),
                          DataCell(
                            Icon(
                              h.estimatedDate ? Icons.check : Icons.close,
                              size: 18,
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: _saving
                                  ? null
                                  : () => _deleteHoliday(h, holidays),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            _editingDate == null
                ? context.tr("admin_five_market_holidays_add")
                : "${context.tr("admin_five_market_holidays_add")} ($_editingDate)",
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _pickedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setState(() => _pickedDate = picked);
                    }
                  },
            icon: const Icon(Icons.date_range_outlined),
            label: Text(
              "${context.tr("admin_five_market_holidays_date")}: ${dateFmt.format(_pickedDate)}",
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: context.tr("admin_five_market_holidays_name"),
              errorText: _formError,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr("admin_five_market_holidays_islamic")),
            value: _isIslamic,
            onChanged: _saving ? null : (v) => setState(() => _isIslamic = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr("admin_five_market_holidays_estimated")),
            value: _estimated,
            onChanged: _saving ? null : (v) => setState(() => _estimated = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_editingDate != null)
                TextButton(
                  onPressed: _saving ? null : _clearForm,
                  child: Text(context.tr("cancel")),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : () => _addOrUpdate(holidays),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_outlined),
                label: Text(context.tr("admin_five_market_holidays_add")),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EodDiagnosticsTab extends ConsumerWidget {
  const _EodDiagnosticsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotsAsync = ref.watch(adminEodSnapshotsProvider);
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminEodSnapshotsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: snapshotsAsync.when(
        loading: () => ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (e, _) => ListView(
          children: [Center(child: Text("$e"))],
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  context.tr("admin_five_market_eod_title"),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(context.tr("admin_five_market_eod_subtitle")),
                const SizedBox(height: 24),
                Text(context.tr("admin_five_market_eod_empty")),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            itemCount: rows.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr("admin_five_market_eod_title"),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(context.tr("admin_five_market_eod_subtitle")),
                    const SizedBox(height: 16),
                  ],
                );
              }
              if (index == 1) return const SizedBox.shrink();

              final row = rows[index - 2];
              final date = (row["date"] as String?) ?? (row["id"] as String? ?? "");
              final tradingDay = row["tradingDay"] == true;
              final kmi = row["kmi30"];
              final gold = row["gold"];
              final kmiMap = kmi is Map ? kmi.cast<String, dynamic>() : null;
              final goldMap = gold is Map ? gold.cast<String, dynamic>() : null;
              final kmiClose = (kmiMap?["closingValue"] as num?)?.toDouble();
              final kmiPct = (kmiMap?["changePercent"] as num?)?.toDouble();
              final goldPct = (goldMap?["changePercent"] as num?)?.toDouble();
              final credited = row["creditedCount"];

              String kmiText = "—";
              if (kmiMap != null && kmiMap["error"] == null) {
                if (kmiClose != null && kmiPct != null) {
                  kmiText =
                      "${kmiClose.toStringAsFixed(2)} (${kmiPct >= 0 ? "+" : ""}${kmiPct.toStringAsFixed(2)}%)";
                } else if (kmiClose != null) {
                  kmiText = kmiClose.toStringAsFixed(2);
                }
              }

              String goldText = "—";
              if (goldMap != null && goldMap["error"] == null && goldPct != null) {
                goldText =
                    "${goldPct >= 0 ? "+" : ""}${goldPct.toStringAsFixed(2)}%";
              }

              final creditedText = credited is num
                  ? context.trParams("admin_five_market_eod_credited", {
                      "n": "${credited.toInt()}",
                    })
                  : "—";

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: scheme.outline.withValues(alpha: 0.15),
                  ),
                ),
                child: ListTile(
                  title: Text(date),
                  subtitle: Text("KMI30: $kmiText · Gold: $goldText · $creditedText"),
                  trailing: Chip(
                    label: Text(
                      tradingDay
                          ? context.tr("admin_five_market_eod_trading")
                          : context.tr("admin_five_market_eod_non_trading"),
                      style: TextStyle(
                        fontSize: 11,
                        color: tradingDay
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    backgroundColor: tradingDay
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
