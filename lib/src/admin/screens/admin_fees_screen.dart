import "package:cloud_firestore/cloud_firestore.dart";
import "package:cloud_functions/cloud_functions.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../core/i18n/app_translations.dart";

/// Admin Fee Management — premium banking-app styled control panel.
class AdminFeesScreen extends ConsumerStatefulWidget {
  const AdminFeesScreen({super.key});

  @override
  ConsumerState<AdminFeesScreen> createState() => _AdminFeesScreenState();
}

class _AdminFeesScreenState extends ConsumerState<AdminFeesScreen> {
  final _fn = FirebaseFunctions.instanceFor(region: "us-central1");
  final _db = FirebaseFirestore.instance;

  final _mgmtCtl = TextEditingController();
  final _perfCtl = TextEditingController();
  final _frontCtl = TextEditingController();
  final _refCtl = TextEditingController();

  bool _isEnabled = false;
  bool _frontEndLoadFirstDepositOnly = false;
  bool _loaded = false;
  bool _saving = false;
  bool _sendingStatements = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _mgmtCtl.dispose();
    _perfCtl.dispose();
    _frontCtl.dispose();
    _refCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await _fn.httpsCallable("getFeeConfig").call();
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;
      setState(() {
        _isEnabled = data["isEnabled"] == true;
        _frontEndLoadFirstDepositOnly =
            data["frontEndLoadFirstDepositOnly"] == true;
        _mgmtCtl.text =
            ((data["managementFeePctAnnual"] as num?)?.toDouble() ?? 0)
                .toStringAsFixed(2);
        _perfCtl.text =
            ((data["performanceFeePct"] as num?)?.toDouble() ?? 0)
                .toStringAsFixed(2);
        _frontCtl.text =
            ((data["frontEndLoadPct"] as num?)?.toDouble() ?? 0)
                .toStringAsFixed(2);
        _refCtl.text =
            ((data["referralFeePct"] as num?)?.toDouble() ?? 0)
                .toStringAsFixed(2);
        _loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loaded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${context.tr("fee_load_failed")}: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double _parsePct(TextEditingController c) {
    final v = double.tryParse(c.text.trim());
    if (v == null) return 0;
    return v.clamp(0, 100).toDouble();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _fn.httpsCallable("saveFeeConfig").call({
        "isEnabled": _isEnabled,
        "managementFeePctAnnual": _parsePct(_mgmtCtl),
        "performanceFeePct": _parsePct(_perfCtl),
        "frontEndLoadPct": _parsePct(_frontCtl),
        "referralFeePct": _parsePct(_refCtl),
        "frontEndLoadFirstDepositOnly": _frontEndLoadFirstDepositOnly,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr("fee_save_ok")),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${context.tr("fee_save_failed")}: ${e.message ?? e.code}"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${context.tr("fee_save_failed")}: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendStatements() async {
    final periodKey = await _pickPeriodKey(context);
    if (periodKey == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr("fee_send_statements_title")),
        content: Text(
          context.tr("fee_send_statements_body").replaceAll("{period}", periodKey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr("cancel")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr("fee_send_statements_action")),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _sendingStatements = true);
    try {
      final result = await _fn.httpsCallable("sendMonthlyFeeStatements").call({
        "periodKey": periodKey,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .tr("fee_statements_done")
                .replaceAll("{written}", "${data["written"] ?? 0}")
                .replaceAll("{period}", periodKey),
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${context.tr("fee_statements_failed")}: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingStatements = false);
    }
  }

  Future<String?> _pickPeriodKey(BuildContext context) async {
    final now = DateTime.now();
    final firstOfThisMonth = DateTime(now.year, now.month, 1);
    final initial = DateTime(firstOfThisMonth.year, firstOfThisMonth.month - 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: context.tr("fee_pick_period"),
    );
    if (picked == null) return null;
    final y = picked.year.toString().padLeft(4, "0");
    final m = picked.month.toString().padLeft(2, "0");
    return "$y-$m";
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PremiumHeroHeader(
            isEnabled: _isEnabled,
            onToggleEnabled: (v) => setState(() => _isEnabled = v),
            onSave: _saving ? null : _save,
            saving: _saving,
            onSendStatements: _sendingStatements ? null : _sendStatements,
            sendingStatements: _sendingStatements,
          ),
          const SizedBox(height: 28),
          Text(
            context.tr("fee_section_rates"),
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final isWide = c.maxWidth >= 980;
              final cards = [
                _FeeRateCard(
                  icon: Icons.account_balance_outlined,
                  accent: const Color(0xFF1E88E5),
                  title: context.tr("fee_card_mgmt_title"),
                  subtitle: context.tr("fee_card_mgmt_subtitle"),
                  controller: _mgmtCtl,
                  helperBuilder: (pct) => _ManagementPreview(pct: pct),
                ),
                _FeeRateCard(
                  icon: Icons.trending_up_rounded,
                  accent: const Color(0xFF00897B),
                  title: context.tr("fee_card_perf_title"),
                  subtitle: context.tr("fee_card_perf_subtitle"),
                  controller: _perfCtl,
                  helperBuilder: (pct) => _PerformancePreview(pct: pct),
                ),
                _FeeRateCard(
                  icon: Icons.input_rounded,
                  accent: const Color(0xFF6A1B9A),
                  title: context.tr("fee_card_front_title"),
                  subtitle: context.tr("fee_card_front_subtitle"),
                  controller: _frontCtl,
                  helperBuilder: (pct) => _FrontEndLoadPreview(
                    pct: pct,
                    firstOnly: _frontEndLoadFirstDepositOnly,
                    onChangeFirstOnly: (v) =>
                        setState(() => _frontEndLoadFirstDepositOnly = v),
                  ),
                ),
                _FeeRateCard(
                  icon: Icons.handshake_outlined,
                  accent: const Color(0xFFEF6C00),
                  title: context.tr("fee_card_referral_title"),
                  subtitle: context.tr("fee_card_referral_subtitle"),
                  controller: _refCtl,
                  helperBuilder: (pct) => _ReferralPreview(pct: pct),
                ),
              ];
              if (!isWide) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      cards[i],
                      if (i != cards.length - 1) const SizedBox(height: 16),
                    ],
                  ],
                );
              }
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final c in cards)
                    SizedBox(width: 460, child: c),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Text(
            context.tr("fee_section_history"),
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _FeeHistoryTable(db: _db),
        ],
      ),
    );
  }
}

class _PremiumHeroHeader extends StatelessWidget {
  const _PremiumHeroHeader({
    required this.isEnabled,
    required this.onToggleEnabled,
    required this.onSave,
    required this.saving,
    required this.onSendStatements,
    required this.sendingStatements,
  });

  final bool isEnabled;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback? onSave;
  final bool saving;
  final VoidCallback? onSendStatements;
  final bool sendingStatements;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final stack = c.maxWidth < 720;
          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.payments_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? Colors.greenAccent.shade400.withValues(alpha: 0.22)
                          : Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isEnabled
                            ? Colors.greenAccent.shade100
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isEnabled
                                ? Colors.greenAccent.shade100
                                : Colors.white70,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isEnabled
                              ? context.tr("fee_status_active")
                              : context.tr("fee_status_disabled"),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                context.tr("fee_management_title"),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr("fee_management_subtitle"),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                ),
              ),
            ],
          );

          final right = Column(
            crossAxisAlignment: stack
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr("fee_master_toggle"),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: isEnabled,
                      activeThumbColor: Colors.greenAccent.shade100,
                      activeTrackColor: Colors.greenAccent.shade400,
                      onChanged: onToggleEnabled,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: onSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: scheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    icon: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      saving
                          ? context.tr("fee_saving")
                          : context.tr("fee_save_action"),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onSendStatements,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    icon: sendingStatements
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.outgoing_mail, size: 18),
                    label: Text(
                      sendingStatements
                          ? context.tr("fee_send_statements_busy")
                          : context.tr("fee_send_statements_action"),
                    ),
                  ),
                ],
              ),
            ],
          );

          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                left,
                const SizedBox(height: 16),
                right,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 24),
              right,
            ],
          );
        },
      ),
    );
  }
}

class _FeeRateCard extends StatelessWidget {
  const _FeeRateCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.helperBuilder,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final TextEditingController controller;
  final Widget Function(double pct) helperBuilder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pct = double.tryParse(controller.text.trim()) ?? 0;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r"^\d{0,3}(\.\d{0,4})?"),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: context.tr("fee_field_rate"),
                        suffixText: "%",
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${pct.toStringAsFixed(2)}%",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              helperBuilder(pct),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementPreview extends StatelessWidget {
  const _ManagementPreview({required this.pct});
  final double pct;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);
    const principal = 1000000.0;
    final yearly = principal * pct / 100;
    final monthly = yearly / 12;
    return _PreviewBox(
      children: [
        Text(
          context.tr("fee_preview_label"),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        _PreviewRow(
          label: context.tr("fee_preview_principal"),
          value: money.format(principal),
        ),
        _PreviewRow(
          label: context.tr("fee_preview_monthly_deduction"),
          value: money.format(monthly),
        ),
        _PreviewRow(
          label: context.tr("fee_preview_yearly_deduction"),
          value: money.format(yearly),
        ),
      ],
    );
  }
}

class _PerformancePreview extends StatelessWidget {
  const _PerformancePreview({required this.pct});
  final double pct;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);
    const sampleProfit = 100.0;
    final fee = sampleProfit * pct / 100;
    final net = sampleProfit - fee;
    return _PreviewBox(
      children: [
        Text(
          context.tr("fee_preview_label"),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        _PreviewRow(
          label: context.tr("fee_preview_gross_profit"),
          value: money.format(sampleProfit),
        ),
        _PreviewRow(
          label: context.tr("fee_preview_fee_deducted"),
          value: "- ${money.format(fee)}",
        ),
        _PreviewRow(
          label: context.tr("fee_preview_net_credited"),
          value: money.format(net),
        ),
      ],
    );
  }
}

class _FrontEndLoadPreview extends StatelessWidget {
  const _FrontEndLoadPreview({
    required this.pct,
    required this.firstOnly,
    required this.onChangeFirstOnly,
  });

  final double pct;
  final bool firstOnly;
  final ValueChanged<bool> onChangeFirstOnly;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);
    const sample = 100000.0;
    final fee = sample * pct / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PreviewBox(
          children: [
            Text(
              context.tr("fee_preview_label"),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            _PreviewRow(
              label: context.tr("fee_preview_deposit"),
              value: money.format(sample),
            ),
            _PreviewRow(
              label: context.tr("fee_preview_front_load_fee"),
              value: "- ${money.format(fee)}",
            ),
            _PreviewRow(
              label: context.tr("fee_preview_invested_principal"),
              value: money.format(sample - fee),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: firstOnly,
          onChanged: onChangeFirstOnly,
          title: Text(
            context.tr("fee_front_first_only_label"),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            context.tr("fee_front_first_only_subtitle"),
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _ReferralPreview extends StatelessWidget {
  const _ReferralPreview({required this.pct});
  final double pct;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);
    const sample = 100000.0;
    final fee = sample * pct / 100;
    return _PreviewBox(
      children: [
        Text(
          context.tr("fee_preview_label"),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        _PreviewRow(
          label: context.tr("fee_preview_first_deposit"),
          value: money.format(sample),
        ),
        _PreviewRow(
          label: context.tr("fee_preview_referral_fee"),
          value: "- ${money.format(fee)}",
        ),
        const SizedBox(height: 6),
        Text(
          context.tr("fee_preview_referral_note"),
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _FeeHistoryTable extends StatelessWidget {
  const _FeeHistoryTable({required this.db});
  final FirebaseFirestore db;

  static const _feeTypes = [
    "front_end_load_fee",
    "referral_fee",
    "management_fee",
    "performance_fee",
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);
    final dateFmt = DateFormat("MMM d, yyyy HH:mm");

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection("transactions")
          .where("type", whereIn: _feeTypes)
          .orderBy("createdAt", descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              "${context.tr("error_prefix")} ${snap.error}",
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long_outlined, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(child: Text(context.tr("fee_history_empty"))),
              ],
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
            itemBuilder: (ctx, i) {
              final d = docs[i].data();
              final ty = (d["type"] as String? ?? "").toLowerCase();
              final amt = (d["amount"] as num?)?.toDouble() ?? 0;
              final period = d["periodKey"] as String? ?? "";
              final createdRaw = d["createdAt"];
              DateTime? created;
              if (createdRaw is Timestamp) created = createdRaw.toDate();
              final user = d["userId"] as String? ?? "—";
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: _accentForFee(ty).withValues(alpha: 0.16),
                  child: Icon(
                    _iconForFee(ty),
                    color: _accentForFee(ty),
                    size: 18,
                  ),
                ),
                title: Text(
                  _labelForFee(context, ty),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  "${user.length > 10 ? "${user.substring(0, 10)}…" : user}"
                  "${period.isNotEmpty ? " · $period" : ""}"
                  "${created != null ? " · ${dateFmt.format(created)}" : ""}",
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Text(
                  "- ${money.format(amt)}",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.error,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Color _accentForFee(String ty) {
    switch (ty) {
      case "front_end_load_fee":
        return const Color(0xFF6A1B9A);
      case "referral_fee":
        return const Color(0xFFEF6C00);
      case "management_fee":
        return const Color(0xFF1E88E5);
      case "performance_fee":
        return const Color(0xFF00897B);
      default:
        return Colors.grey;
    }
  }

  IconData _iconForFee(String ty) {
    switch (ty) {
      case "front_end_load_fee":
        return Icons.input_rounded;
      case "referral_fee":
        return Icons.handshake_outlined;
      case "management_fee":
        return Icons.account_balance_outlined;
      case "performance_fee":
        return Icons.trending_up_rounded;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  String _labelForFee(BuildContext context, String ty) {
    switch (ty) {
      case "front_end_load_fee":
        return context.tr("fee_label_front_load");
      case "referral_fee":
        return context.tr("fee_label_referral");
      case "management_fee":
        return context.tr("fee_label_management");
      case "performance_fee":
        return context.tr("fee_label_performance");
      default:
        return ty;
    }
  }
}
