import "package:cloud_functions/cloud_functions.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../core/i18n/app_translations.dart";
import "../../core/i18n/language_provider.dart";
import "../../core/theme/theme_provider.dart";
import "../providers/admin_providers.dart";
import "../providers/admin_transaction_providers.dart";

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int? _users;
  int? _pendingKyc;
  String? _loadError;
  bool _repairing = false;
  String? _corsMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stats = ref.read(adminStatsServiceProvider);
      final u = await stats.countUsers();
      final k = await stats.countPendingKyc();
      if (mounted) {
        setState(() {
          _users = u;
          _pendingKyc = k;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = e.toString());
      }
    }
  }

  Future<void> _repairBalances() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Recalculate all balances?"),
        content: const Text(
          "This will re-read every user's transaction history and rewrite "
          "their wallet balances from scratch.\n\n"
          "Use this once to fix any data inconsistencies. "
          "The operation is safe and non-destructive to transaction records.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Recalculate"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _repairing = true);
    try {
      final fn = FirebaseFunctions.instanceFor(region: "us-central1");
      final result = await fn.httpsCallable("repairUserBalances").call();
      final data = result.data as Map<String, dynamic>? ?? {};
      final fixed = data["fixedCount"] ?? 0;
      final total = data["totalUsers"] ?? 0;
      final errors = data["errorCount"] ?? 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Done. Fixed $fixed / $total users."
            "${errors > 0 ? " ($errors errors — check logs)" : ""}",
          ),
          backgroundColor: errors > 0 ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Repair failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _repairing = false);
    }
  }

  Future<void> _runSetCors() async {
    setState(() => _corsMessage = "Setting CORS…");
    try {
      final fn = FirebaseFunctions.instanceFor(region: "us-central1");
      await fn.httpsCallable("setStorageCors").call();
      if (mounted) {
        setState(() => _corsMessage = "CORS configured. Reload the page to load images.");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _corsMessage = "CORS setup failed: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(adminOverviewStatsProvider);
    final currency = NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr("overview"),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            "Operational snapshot for Wakalat Invest.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          if (_corsMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_corsMessage!, style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
            ),
          if (_loadError != null)
            Material(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_loadError!),
              ),
            ),

          // ── Static stat cards (Users + KYC) ───────────────────────────
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              _StatCard(
                title: context.tr("total_users"),
                value: _users == null ? "—" : "$_users",
                icon: Icons.people_outline,
                onOpen: () {},
              ),
              _StatCard(
                title: context.tr("pending_kyc"),
                subtitle: "pending + under review",
                value: _pendingKyc == null ? "—" : "$_pendingKyc",
                icon: Icons.pending_actions_outlined,
                onOpen: () => context.go("/kyc"),
              ),

              // ── Live stat cards from transactions stream ───────────────
              overviewAsync.when(
                loading: () => const _StatCard(
                  title: "Pending deposits",
                  value: "…",
                  icon: Icons.inbox_outlined,
                ),
                error: (e, _) => const _StatCard(
                  title: "Pending deposits",
                  value: "err",
                  icon: Icons.inbox_outlined,
                ),
                data: (stats) => _StatCard(
                  title: "Pending deposits",
                  value: "${stats["pendingDeposits"] ?? 0}",
                  icon: Icons.inbox_outlined,
                  onOpen: () => context.go("/deposits"),
                ),
              ),
              overviewAsync.when(
                loading: () => const _StatCard(
                  title: "Pending withdrawals",
                  value: "…",
                  icon: Icons.outbox_outlined,
                ),
                error: (e, _) => const _StatCard(
                  title: "Pending withdrawals",
                  value: "err",
                  icon: Icons.outbox_outlined,
                ),
                data: (stats) => _StatCard(
                  title: "Pending withdrawals",
                  value: "${stats["pendingWithdrawals"] ?? 0}",
                  icon: Icons.outbox_outlined,
                  onOpen: () => context.go("/withdrawals"),
                ),
              ),
              overviewAsync.when(
                loading: () => const _StatCard(
                  title: "Total deposited",
                  value: "…",
                  icon: Icons.account_balance_outlined,
                ),
                error: (e, _) => const _StatCard(
                  title: "Total deposited",
                  value: "err",
                  icon: Icons.account_balance_outlined,
                ),
                data: (stats) => _StatCard(
                  title: "Total deposited",
                  subtitle: "approved deposits",
                  value: currency.format(stats["totalDeposited"] ?? 0),
                  icon: Icons.account_balance_outlined,
                ),
              ),
              overviewAsync.when(
                loading: () => const _StatCard(
                  title: "Total profit distributed",
                  value: "…",
                  icon: Icons.trending_up_rounded,
                ),
                error: (e, _) => const _StatCard(
                  title: "Total profit distributed",
                  value: "err",
                  icon: Icons.trending_up_rounded,
                ),
                data: (stats) => _StatCard(
                  title: "Total profit distributed",
                  subtitle: "approved profit entries",
                  value: currency.format(stats["totalProfit"] ?? 0),
                  icon: Icons.trending_up_rounded,
                ),
              ),
              overviewAsync.when(
                loading: () => const _StatCard(
                  title: "Total withdrawn",
                  value: "…",
                  icon: Icons.north_east_rounded,
                ),
                error: (e, _) => const _StatCard(
                  title: "Total withdrawn",
                  value: "err",
                  icon: Icons.north_east_rounded,
                ),
                data: (stats) => _StatCard(
                  title: "Total withdrawn",
                  subtitle: "approved withdrawals",
                  value: currency.format(stats["totalWithdrawn"] ?? 0),
                  icon: Icons.north_east_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          _AdminPreferencesCard(),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => context.go("/kyc"),
                icon: const Icon(Icons.arrow_forward),
                label: Text(context.tr("kyc_queue")),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go("/deposits"),
                icon: const Icon(Icons.inbox_outlined),
                label: Text(context.tr("deposits")),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go("/withdrawals"),
                icon: const Icon(Icons.outbox_outlined),
                label: Text(context.tr("withdrawals")),
              ),
              OutlinedButton.icon(
                onPressed: _repairing ? null : _repairBalances,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade700,
                  side: BorderSide(color: Colors.orange.shade300),
                ),
                icon: _repairing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.calculate_outlined),
                label: Text(_repairing
                    ? "Recalculating…"
                    : "Recalculate all balances"),
              ),
              OutlinedButton.icon(
                onPressed: () => _runSetCors(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  side: BorderSide(color: Colors.blue.shade300),
                ),
                icon: const Icon(Icons.dns_outlined),
                label: const Text("Fix Storage CORS"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminPreferencesCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider).valueOrNull ?? ThemeMode.light;
    final locale = ref.watch(languageProvider).valueOrNull ?? const Locale("en");
    final isDark = themeMode == ThemeMode.dark;

    return SizedBox(
      width: 580,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr("app_preferences"),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr("dark_mode"),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  Switch(
                    value: isDark,
                    onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  const Icon(Icons.language_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr("language"),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(value: "en", label: Text("EN")),
                      ButtonSegment<String>(value: "ur", label: Text("اردو")),
                    ],
                    selected: {locale.languageCode == "ur" ? "ur" : "en"},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => ref
                        .read(languageProvider.notifier)
                        .setLanguage(v.first),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.onOpen,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onOpen;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon,
                    size: 28,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (onOpen != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Tap to view →",
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
