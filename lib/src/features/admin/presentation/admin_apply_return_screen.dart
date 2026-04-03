import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../models/portfolio_model.dart";
import "../../../providers/auth_providers.dart";
import "../../../providers/portfolio_providers.dart";
import "widgets/admin_user_return_tile_widget.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);

enum _ReturnMode { percentage, manual }

class AdminApplyReturnScreen extends ConsumerStatefulWidget {
  const AdminApplyReturnScreen({super.key});

  @override
  ConsumerState<AdminApplyReturnScreen> createState() =>
      _AdminApplyReturnScreenState();
}

class _AdminApplyReturnScreenState
    extends ConsumerState<AdminApplyReturnScreen> {
  _ReturnMode _mode = _ReturnMode.percentage;
  final _pctController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = "";

  // Per-user controllers for manual mode: uid → controller
  final Map<String, TextEditingController> _manualControllers = {};
  final Map<String, bool> _processingUser = {};
  bool _processingAll = false;

  @override
  void dispose() {
    _pctController.dispose();
    _searchController.dispose();
    for (final c in _manualControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String uid) {
    return _manualControllers.putIfAbsent(uid, TextEditingController.new);
  }

  // ── Confirmation dialog ───────────────────────────────────────────────────

  Future<bool> _confirmDialog({
    required String mode,
    required String returnInfo,
    required int affectedUsers,
    required String estimatedProfit,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text(
              "Confirm return application",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.heading,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ConfirmRow(label: "Mode", value: mode),
                _ConfirmRow(label: "Return", value: returnInfo),
                _ConfirmRow(label: "Affected users", value: "$affectedUsers"),
                _ConfirmRow(label: "Est. total profit", value: estimatedProfit),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text(
                    "This action will update portfolio balances and write to the transaction ledger. It cannot be undone.",
                    style: TextStyle(fontSize: 12, color: AppColors.body),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Confirm & apply"),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Summary dialog ────────────────────────────────────────────────────────

  void _showSummary(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 22,
            ),
            const SizedBox(width: 8),
            const Text(
              "Return applied",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(
              label: "Successful",
              value: "${result["successCount"]} users",
            ),
            if ((result["failCount"] as int? ?? 0) > 0)
              _ConfirmRow(
                label: "Failed",
                value: "${result["failCount"]} users",
                valueColor: AppColors.error,
              ),
            _ConfirmRow(
              label: "Total profit distributed",
              value: _money.format(result["totalProfit"] ?? 0),
            ),
            if ((result["errors"] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              const Text(
                "Errors:",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
              ...((result["errors"] as List)
                  .take(3)
                  .map(
                    (e) => Text(
                      "• $e",
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.error,
                      ),
                    ),
                  )),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  // ── Mode A: apply % to all ────────────────────────────────────────────────

  Future<void> _applyPercentageToAll(List<PortfolioModel> portfolios) async {
    final pct = double.tryParse(_pctController.text.trim());
    if (pct == null || pct <= 0) {
      _toast("Enter a valid percentage.");
      return;
    }

    final estimatedTotal = portfolios.fold<double>(
      0,
      (sum, p) => sum + p.currentValue * pct / 100,
    );

    final confirmed = await _confirmDialog(
      mode: "Percentage — all users",
      returnInfo: "$pct%",
      affectedUsers: portfolios.length,
      estimatedProfit: _money.format(estimatedTotal),
    );
    if (!confirmed) return;

    setState(() => _processingAll = true);
    try {
      final result = await ref
          .read(applyReturnProvider.notifier)
          .applyPercentageToAll(pct);
      if (!mounted) return;
      _showSummary(result);
      // Invalidate so list refreshes on next load
      ref.invalidate(allPortfoliosProvider);
    } catch (e) {
      if (!mounted) return;
      _toast("Error: $e");
    } finally {
      if (mounted) setState(() => _processingAll = false);
    }
  }

  // ── Mode B: apply manual per user ─────────────────────────────────────────

  Future<void> _applyManualToUser(
    String uid,
    String userName,
    double currentValue,
  ) async {
    final controller = _controllerFor(uid);
    final profit = double.tryParse(controller.text.trim());
    if (profit == null || profit <= 0) {
      _toast("Enter a valid profit amount for $userName.");
      return;
    }

    final confirmed = await _confirmDialog(
      mode: "Manual — single user",
      returnInfo: _money.format(profit),
      affectedUsers: 1,
      estimatedProfit: _money.format(profit),
    );
    if (!confirmed) return;

    setState(() => _processingUser[uid] = true);
    try {
      final applied = await ref
          .read(applyReturnProvider.notifier)
          .applyManualToUser(uid: uid, profitAmount: profit);
      if (!mounted) return;
      _showSummary({
        "successCount": 1,
        "failCount": 0,
        "totalProfit": applied,
        "errors": [],
      });
      controller.clear();
      ref.invalidate(allPortfoliosProvider);
    } catch (e) {
      if (!mounted) return;
      _toast("Failed for $userName: $e");
    } finally {
      if (mounted) setState(() => _processingUser[uid] = false);
    }
  }

  Future<void> _applyAllManual(
    List<Map<String, dynamic>> users,
    List<PortfolioModel> portfolios,
  ) async {
    // Only apply to users who have a non-empty profit field
    final toApply = users.where((u) {
      final uid = u["id"] as String;
      final val = _controllerFor(uid).text.trim();
      return val.isNotEmpty && double.tryParse(val) != null;
    }).toList();

    if (toApply.isEmpty) {
      _toast("Enter profit amounts for at least one user.");
      return;
    }

    double totalEstimate = 0;
    for (final u in toApply) {
      totalEstimate +=
          double.tryParse(_controllerFor(u["id"] as String).text.trim()) ?? 0;
    }

    final confirmed = await _confirmDialog(
      mode: "Manual — ${toApply.length} users",
      returnInfo: "Various amounts",
      affectedUsers: toApply.length,
      estimatedProfit: _money.format(totalEstimate),
    );
    if (!confirmed) return;

    setState(() => _processingAll = true);
    int successCount = 0;
    int failCount = 0;
    double totalProfit = 0;
    final List<String> errors = [];

    for (final u in toApply) {
      final uid = u["id"] as String;
      final profit = double.tryParse(_controllerFor(uid).text.trim()) ?? 0;
      try {
        final applied = await ref
            .read(applyReturnProvider.notifier)
            .applyManualToUser(uid: uid, profitAmount: profit);
        totalProfit += applied;
        successCount++;
        _controllerFor(uid).clear();
      } catch (e) {
        failCount++;
        errors.add("${u["name"] ?? uid}: $e");
      }
    }

    if (!mounted) return;
    setState(() => _processingAll = false);
    _showSummary({
      "successCount": successCount,
      "failCount": failCount,
      "totalProfit": totalProfit,
      "errors": errors,
    });
    ref.invalidate(allPortfoliosProvider);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    if (profile == null || !profile.isAdmin) {
      return AppScaffold(
        title: "Apply Returns",
        showNotificationAction: false,
        body: const Center(child: Text("Admin access required.")),
      );
    }

    return AppScaffold(
      title: "Apply Monthly Return",
      showNotificationAction: false,
      body: Column(
        children: [
          // Mode toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SegmentedButton<_ReturnMode>(
              segments: const [
                ButtonSegment(
                  value: _ReturnMode.percentage,
                  label: Text("% All users"),
                  icon: Icon(Icons.group_rounded, size: 16),
                ),
                ButtonSegment(
                  value: _ReturnMode.manual,
                  label: Text("Manual per user"),
                  icon: Icon(Icons.person_rounded, size: 16),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _mode == _ReturnMode.percentage
                ? _PercentageModeTab(
                    pctController: _pctController,
                    onApply: _applyPercentageToAll,
                    isProcessing: _processingAll,
                  )
                : _ManualModeTab(
                    searchController: _searchController,
                    searchQuery: _searchQuery,
                    onSearchChanged: (q) => setState(() => _searchQuery = q),
                    controllerFor: _controllerFor,
                    onApplyUser: _applyManualToUser,
                    onApplyAll: _applyAllManual,
                    processingUser: _processingUser,
                    isProcessingAll: _processingAll,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Mode A tab ────────────────────────────────────────────────────────────────

class _PercentageModeTab extends ConsumerWidget {
  const _PercentageModeTab({
    required this.pctController,
    required this.onApply,
    required this.isProcessing,
  });

  final TextEditingController pctController;
  final Future<void> Function(List<PortfolioModel>) onApply;
  final bool isProcessing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfoliosAsync = ref.watch(allPortfoliosProvider);

    return portfoliosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Error loading portfolios: $e")),
      data: (portfolios) {
        final pctText = pctController.text.trim();
        final pct = double.tryParse(pctText) ?? 0;
        final totalEstimate = portfolios.fold<double>(
          0,
          (s, p) => s + p.currentValue * pct / 100,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              _InfoCard(
                message:
                    "This will apply a single return percentage to all ${portfolios.length} active portfolio(s).",
              ),
              const SizedBox(height: 16),

              // Input
              TextField(
                controller: pctController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => (context as Element).markNeedsBuild(),
                decoration: const InputDecoration(
                  labelText: "Monthly return %",
                  hintText: "e.g. 5.0",
                  prefixIcon: Icon(Icons.percent_rounded),
                ),
              ),
              const SizedBox(height: 12),

              // Preview
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  children: [
                    _PreviewRow(
                      label: "Portfolios affected",
                      value: "${portfolios.length}",
                    ),
                    _PreviewRow(
                      label: "Return rate",
                      value: pct > 0 ? "$pct%" : "—",
                    ),
                    _PreviewRow(
                      label: "Est. total profit",
                      value: pct > 0 ? _money.format(totalEstimate) : "—",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: (isProcessing || portfolios.isEmpty)
                      ? null
                      : () => onApply(portfolios),
                  icon: isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    isProcessing ? "Processing…" : "Apply to all users",
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Mode B tab ────────────────────────────────────────────────────────────────

class _ManualModeTab extends ConsumerWidget {
  const _ManualModeTab({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.controllerFor,
    required this.onApplyUser,
    required this.onApplyAll,
    required this.processingUser,
    required this.isProcessingAll,
  });

  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final TextEditingController Function(String uid) controllerFor;
  final Future<void> Function(String uid, String name, double value)
  onApplyUser;
  final Future<void> Function(
    List<Map<String, dynamic>> users,
    List<PortfolioModel> portfolios,
  )
  onApplyAll;
  final Map<String, bool> processingUser;
  final bool isProcessingAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersForAdminProvider);
    final portfoliosAsync = ref.watch(allPortfoliosProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Error: $e")),
      data: (users) {
        final portfolioMap = portfoliosAsync.valueOrNull != null
            ? {for (final p in portfoliosAsync.valueOrNull!) p.uid: p}
            : <String, PortfolioModel>{};

        final filtered = users
            .where(
              (u) =>
                  searchQuery.isEmpty ||
                  (u["name"] as String? ?? "").toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ) ||
                  (u["email"] as String? ?? "").toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ),
            )
            .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  labelText: "Search users",
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: isProcessingAll
                      ? null
                      : () => onApplyAll(
                          filtered,
                          portfoliosAsync.valueOrNull ?? [],
                        ),
                  icon: isProcessingAll
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text("Apply all entered"),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final u = filtered[i];
                  final uid = u["id"] as String;
                  final portfolio = portfolioMap[uid];
                  return AdminUserReturnTile(
                    userName: (u["name"] as String?) ?? "Unknown",
                    userEmail: (u["email"] as String?) ?? "",
                    currentValue: portfolio?.currentValue ?? 0,
                    controller: controllerFor(uid),
                    isProcessing: processingUser[uid] == true,
                    onApply: () => onApplyUser(
                      uid,
                      (u["name"] as String?) ?? "Unknown",
                      portfolio?.currentValue ?? 0,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Shared helper widgets ─────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.blue.shade700,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.bodyMuted),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.heading,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.bodyMuted),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.heading,
            ),
          ),
        ],
      ),
    );
  }
}
