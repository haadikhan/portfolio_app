import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/i18n/language_provider.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/theme/theme_provider.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../providers/profile_providers.dart";

class InvestorProfileScreen extends ConsumerWidget {
  const InvestorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(investorProfileProvider);

    return AppScaffold(
      title: context.tr("profile"),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text("Error: $e",
              style: const TextStyle(color: AppColors.error)),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text("Profile not found."));
          }
          return _ProfileBody(profile: profile);
        },
      ),
    );
  }
}

// ── Profile body ──────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerStatefulWidget {
  const _ProfileBody({required this.profile});
  final InvestorProfile profile;

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  bool _editing = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.profile.name;
    _phoneCtrl.text = widget.profile.phone ?? "";
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveDirectFields() async {
    final notifier = ref.read(profileUpdateProvider.notifier);
    await notifier.saveDirectFields(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Profile updated successfully."),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _openBankEditDialog() async {
    final bankCtrl =
        TextEditingController(text: widget.profile.bankName ?? "");
    final acctCtrl =
        TextEditingController(text: widget.profile.accountNumber ?? "");
    final titleCtrl =
        TextEditingController(text: widget.profile.accountTitle ?? "");

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Update bank details"),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: AppColors.warning),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Bank detail changes require admin approval. Your request will be reviewed within 24 hours.",
                          style: TextStyle(fontSize: 11, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DialogField(
                    label: "Bank name", controller: bankCtrl),
                const SizedBox(height: 10),
                _DialogField(
                    label: "Account number", controller: acctCtrl),
                const SizedBox(height: 10),
                _DialogField(
                    label: "Account title", controller: titleCtrl),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Submit for review")),
        ],
      ),
    );

    bankCtrl.dispose();
    acctCtrl.dispose();
    titleCtrl.dispose();

    if (confirmed != true || !mounted) return;

    await ref.read(profileUpdateProvider.notifier).submitPendingChange({
      "bankName": bankCtrl.text.trim(),
      "accountNumber": acctCtrl.text.trim(),
      "accountTitle": titleCtrl.text.trim(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            "Your request has been submitted for admin review."),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _openNomineeEditDialog() async {
    final nameCtrl =
        TextEditingController(text: widget.profile.nomineeName ?? "");
    final cnicCtrl =
        TextEditingController(text: widget.profile.nomineeCnic ?? "");
    final relCtrl =
        TextEditingController(text: widget.profile.nomineeRelation ?? "");

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Update nominee details"),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: AppColors.warning),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Nominee detail changes require admin approval.",
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DialogField(
                    label: "Nominee name", controller: nameCtrl),
                const SizedBox(height: 10),
                _DialogField(
                    label: "Nominee CNIC", controller: cnicCtrl),
                const SizedBox(height: 10),
                _DialogField(
                    label: "Relation", controller: relCtrl),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Submit for review")),
        ],
      ),
    );

    nameCtrl.dispose();
    cnicCtrl.dispose();
    relCtrl.dispose();

    if (confirmed != true || !mounted) return;

    await ref.read(profileUpdateProvider.notifier).submitPendingChange({
      "nomineeName": nameCtrl.text.trim(),
      "nomineeCnic": cnicCtrl.text.trim(),
      "nomineeRelation": relCtrl.text.trim(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            "Your request has been submitted for admin review."),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(profileUpdateProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Profile header ─────────────────────────────────────────
          _ProfileHeader(profile: widget.profile),
          const SizedBox(height: 20),

          // ── Edit toggle ────────────────────────────────────────────
          Row(
            children: [
              const Spacer(),
              if (_editing) ...[
                OutlinedButton(
                  onPressed: () => setState(() {
                    _editing = false;
                    _nameCtrl.text = widget.profile.name;
                    _phoneCtrl.text = widget.profile.phone ?? "";
                  }),
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed:
                      updateState.isLoading ? null : _saveDirectFields,
                  icon: updateState.isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 16),
                  label: const Text("Save"),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary),
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: () => setState(() => _editing = true),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text("Edit profile"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Personal info card ──────────────────────────────────────
          _ProfileCard(
            title: "Personal information",
            icon: Icons.person_outline_rounded,
            children: [
              _editing
                  ? _EditableField(
                      label: "Full name",
                      controller: _nameCtrl,
                    )
                  : _ProfileFieldTile(
                      label: "Full name",
                      value: widget.profile.name.isNotEmpty
                          ? widget.profile.name
                          : null,
                    ),
              const Divider(height: 1),
              _editing
                  ? _EditableField(
                      label: "Phone number",
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                    )
                  : _ProfileFieldTile(
                      label: "Phone number",
                      value: widget.profile.phone,
                    ),
              const Divider(height: 1),
              _ProfileFieldTile(
                label: "CNIC",
                value: widget.profile.cnic,
                locked: true,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Bank details card ───────────────────────────────────────
          _ProfileCard(
            title: "Bank details",
            icon: Icons.account_balance_outlined,
            trailingAction: TextButton.icon(
              onPressed: _openBankEditDialog,
              icon: const Icon(Icons.edit_rounded, size: 14),
              label: const Text("Edit", style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
            children: [
              _ProfileFieldTile(
                  label: "Bank name",
                  value: widget.profile.bankName),
              const Divider(height: 1),
              _ProfileFieldTile(
                  label: "Account number",
                  value: widget.profile.accountNumber),
              const Divider(height: 1),
              _ProfileFieldTile(
                  label: "Account title",
                  value: widget.profile.accountTitle),
            ],
          ),
          const SizedBox(height: 14),

          // ── Nominee card ────────────────────────────────────────────
          _ProfileCard(
            title: "Nominee",
            icon: Icons.people_outline_rounded,
            trailingAction: TextButton.icon(
              onPressed: _openNomineeEditDialog,
              icon: const Icon(Icons.edit_rounded, size: 14),
              label: const Text("Edit", style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
            children: [
              _ProfileFieldTile(
                  label: "Nominee name",
                  value: widget.profile.nomineeName),
              const Divider(height: 1),
              _ProfileFieldTile(
                  label: "Nominee CNIC",
                  value: widget.profile.nomineeCnic),
              const Divider(height: 1),
              _ProfileFieldTile(
                  label: "Relation",
                  value: widget.profile.nomineeRelation),
            ],
          ),
          const SizedBox(height: 14),
          _AppPreferencesCard(),

          const SizedBox(height: 20),

          // ── Pending changes note ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 15, color: AppColors.bodyMuted),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Changes to bank details and nominee require admin approval. You will be notified once reviewed.",
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.bodyMuted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppPreferencesCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider).valueOrNull ?? ThemeMode.light;
    final locale = ref.watch(languageProvider).valueOrNull ?? const Locale("en");
    final isDark = themeMode == ThemeMode.dark;
    final isUrdu = locale.languageCode == "ur";

    return _ProfileCard(
      title: context.tr("app_preferences"),
      icon: Icons.tune_rounded,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr("dark_mode"),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.heading),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDark
                          ? context.tr("dark_mode")
                          : context.tr("light_mode"),
                      style: const TextStyle(fontSize: 11, color: AppColors.bodyMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isDark,
                onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.language_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr("language"),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.heading),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUrdu ? context.tr("urdu") : context.tr("english"),
                      style: const TextStyle(fontSize: 11, color: AppColors.bodyMuted),
                    ),
                  ],
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
        ),
      ],
    );
  }
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});
  final InvestorProfile profile;

  @override
  Widget build(BuildContext context) {
    final initials = profile.name.isNotEmpty
        ? profile.name
            .trim()
            .split(" ")
            .map((w) => w[0].toUpperCase())
            .take(2)
            .join()
        : "?";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name.isNotEmpty ? profile.name : "Investor",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  profile.email,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile card ──────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.title,
    required this.icon,
    required this.children,
    this.trailingAction,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heading,
                  ),
                ),
                if (trailingAction != null) ...[
                  const Spacer(),
                  trailingAction!,
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          ...children,
        ],
      ),
    );
  }
}

// ── Profile field tile (read-only) ────────────────────────────────────────────

class _ProfileFieldTile extends StatelessWidget {
  const _ProfileFieldTile({
    required this.label,
    this.value,
    this.locked = false,
  });

  final String label;
  final String? value;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final displayValue =
        (value != null && value!.isNotEmpty) ? value! : "Not added";
    final isEmpty = value == null || value!.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.bodyMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isEmpty
                        ? AppColors.bodyMuted
                        : AppColors.heading,
                    fontStyle:
                        isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          if (locked)
            const Icon(Icons.lock_outline_rounded,
                size: 16, color: AppColors.bodyMuted),
        ],
      ),
    );
  }
}

// ── Editable field (inline edit mode) ────────────────────────────────────────

class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: AppColors.heading),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              fontSize: 12, color: AppColors.bodyMuted),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }
}

// ── Dialog text field ─────────────────────────────────────────────────────────

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.label,
    required this.controller,
  });

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
