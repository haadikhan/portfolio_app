import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/i18n/language_provider.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/theme/theme_provider.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../models/app_user.dart";
import "../../../providers/auth_providers.dart";
import "../../../providers/profile_providers.dart";

/// Prefer `users/{uid}` field when set; otherwise show value from KYC doc.
String? _preferProfileThenKyc(String? profileField, String? kycField) {
  final p = profileField?.trim();
  if (p != null && p.isNotEmpty) return p;
  final k = kycField?.trim();
  if (k != null && k.isNotEmpty) return k;
  return null;
}

String _kycLifecycleBadgeLabel(BuildContext context, KycLifecycleStatus s) {
  return switch (s) {
    KycLifecycleStatus.approved => context.tr("kyc_badge_verified"),
    KycLifecycleStatus.underReview => context.tr("kyc_badge_in_review"),
    KycLifecycleStatus.rejected => context.tr("kyc_badge_rejected"),
    KycLifecycleStatus.pending => context.tr("kyc_badge_pending"),
  };
}

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
          child: Text("${context.tr("error_prefix")} $e",
              style: const TextStyle(color: AppColors.error)),
        ),
        data: (profile) {
          if (profile == null) {
            return Center(child: Text(context.tr("profile_not_found")));
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
      SnackBar(
        content: Text(context.tr("profile_updated")),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _openBankEditDialog() async {
    final kyc = ref.read(userKycProvider).valueOrNull;
    final bankCtrl = TextEditingController(
      text: _preferProfileThenKyc(widget.profile.bankName, kyc?.bankName) ?? "",
    );
    final acctCtrl = TextEditingController(
      text: _preferProfileThenKyc(
            widget.profile.accountNumber,
            kyc?.ibanOrAccountNumber,
          ) ??
          "",
    );
    final titleCtrl = TextEditingController(
      text: _preferProfileThenKyc(
            widget.profile.accountTitle,
            kyc?.accountTitle,
          ) ??
          "",
    );
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            title: Text(
              context.tr("update_bank_title"),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            scrollable: true,
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
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
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr("bank_approval_note"),
                            style: const TextStyle(fontSize: 11, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DialogField(
                    label: context.tr("bank_name"),
                    controller: bankCtrl,
                  ),
                  const SizedBox(height: 10),
                  _DialogField(
                    label: context.tr("account_number"),
                    controller: acctCtrl,
                  ),
                  const SizedBox(height: 10),
                  _DialogField(
                    label: context.tr("account_title"),
                    controller: titleCtrl,
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  context.tr("cancel"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  context.tr("submit_for_review_btn"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          );
        },
      );

      final bankName = bankCtrl.text.trim();
      final accountNumber = acctCtrl.text.trim();
      final accountTitle = titleCtrl.text.trim();
      if (confirmed != true || !mounted) return;

      await ref.read(profileUpdateProvider.notifier).submitPendingChange({
        "bankName": bankName,
        "accountNumber": accountNumber,
        "accountTitle": accountTitle,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr("bank_request_submitted")),
          backgroundColor: AppColors.success,
        ),
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        bankCtrl.dispose();
        acctCtrl.dispose();
        titleCtrl.dispose();
      });
    }
  }

  Future<void> _openNomineeEditDialog() async {
    final kyc = ref.read(userKycProvider).valueOrNull;
    final nameCtrl = TextEditingController(
      text: _preferProfileThenKyc(widget.profile.nomineeName, kyc?.nomineeName) ??
          "",
    );
    final cnicCtrl = TextEditingController(
      text: _preferProfileThenKyc(
            widget.profile.nomineeCnic,
            kyc?.nomineeCnic,
          ) ??
          "",
    );
    final relCtrl = TextEditingController(
      text: _preferProfileThenKyc(
            widget.profile.nomineeRelation,
            kyc?.nomineeRelation,
          ) ??
          "",
    );
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            title: Text(
              context.tr("update_nominee_title"),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            scrollable: true,
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr("nominee_approval_note"),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DialogField(
                    label: context.tr("nominee_name"),
                    controller: nameCtrl,
                  ),
                  const SizedBox(height: 10),
                  _DialogField(
                    label: context.tr("nominee_cnic"),
                    controller: cnicCtrl,
                  ),
                  const SizedBox(height: 10),
                  _DialogField(
                    label: context.tr("relationship"),
                    controller: relCtrl,
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  context.tr("cancel"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  context.tr("submit_for_review_btn"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          );
        },
      );

      final nomineeName = nameCtrl.text.trim();
      final nomineeCnic = cnicCtrl.text.trim();
      final nomineeRelation = relCtrl.text.trim();
      if (confirmed != true || !mounted) return;

      await ref.read(profileUpdateProvider.notifier).submitPendingChange({
        "nomineeName": nomineeName,
        "nomineeCnic": nomineeCnic,
        "nomineeRelation": nomineeRelation,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr("bank_request_submitted")),
          backgroundColor: AppColors.success,
        ),
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameCtrl.dispose();
        cnicCtrl.dispose();
        relCtrl.dispose();
      });
    }
  }

  void _openChangePasswordDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => const _ChangePasswordDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(profileUpdateProvider);
    final kycAsync = ref.watch(userKycProvider);
    final kycRecord = kycAsync.valueOrNull;
    final displayPhone =
        _preferProfileThenKyc(widget.profile.phone, kycRecord?.phone);
    final displayCnic =
        _preferProfileThenKyc(widget.profile.cnic, kycRecord?.cnicNumber);
    final displayBankName =
        _preferProfileThenKyc(widget.profile.bankName, kycRecord?.bankName);
    final displayAccountNumber = _preferProfileThenKyc(
      widget.profile.accountNumber,
      kycRecord?.ibanOrAccountNumber,
    );
    final displayAccountTitle = _preferProfileThenKyc(
      widget.profile.accountTitle,
      kycRecord?.accountTitle,
    );
    final displayNomineeName = _preferProfileThenKyc(
      widget.profile.nomineeName,
      kycRecord?.nomineeName,
    );
    final displayNomineeCnic = _preferProfileThenKyc(
      widget.profile.nomineeCnic,
      kycRecord?.nomineeCnic,
    );
    final displayNomineeRelation = _preferProfileThenKyc(
      widget.profile.nomineeRelation,
      kycRecord?.nomineeRelation,
    );
    final hasPasswordProvider = FirebaseAuth.instance.currentUser?.providerData
            .any((p) => p.providerId == "password") ??
        false;

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
                    _phoneCtrl.text = displayPhone ?? "";
                  }),
                  child: Text(context.tr("cancel")),
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
                  label: Text(context.tr("save_btn")),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary),
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _nameCtrl.text = widget.profile.name;
                    _phoneCtrl.text = displayPhone ?? "";
                    _editing = true;
                  }),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text(context.tr("edit_profile_btn")),
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
            title: context.tr("personal_information"),
            icon: Icons.person_outline_rounded,
            children: [
              _ProfileFieldTile(
                label: context.tr("email_address"),
                value: widget.profile.email.isNotEmpty
                    ? widget.profile.email
                    : null,
                locked: true,
              ),
              const Divider(height: 1),
              _editing
                  ? _EditableField(
                      label: context.tr("full_name"),
                      controller: _nameCtrl,
                    )
                  : _ProfileFieldTile(
                      label: context.tr("full_name"),
                      value: widget.profile.name.isNotEmpty
                          ? widget.profile.name
                          : null,
                    ),
              const Divider(height: 1),
              _editing
                  ? _EditableField(
                      label: context.tr("profile_phone_number"),
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    )
                  : _ProfileFieldTile(
                      label: context.tr("profile_phone_number"),
                      value: displayPhone,
                    ),
              const Divider(height: 1),
              _ProfileFieldTile(
                label: context.tr("cnic_label"),
                value: displayCnic,
                locked: true,
              ),
              const Divider(height: 1),
              _ProfileFieldTile(
                label: context.tr("profile_kyc_status_label"),
                value: _kycLifecycleBadgeLabel(
                  context,
                  widget.profile.kycStatus,
                ),
                locked: true,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Bank details card ───────────────────────────────────────
          _ProfileCard(
            title: context.tr("bank_details_section"),
            icon: Icons.account_balance_outlined,
            trailingAction: TextButton.icon(
              onPressed: _openBankEditDialog,
              icon: const Icon(Icons.edit_rounded, size: 14),
              label: Text(context.tr("edit_short"),
                  style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
            children: [
              _ProfileFieldTile(
                  label: context.tr("bank_name"),
                  value: displayBankName),
              const Divider(height: 1),
              _ProfileFieldTile(
                  label: context.tr("account_number"),
                  value: displayAccountNumber),
              const Divider(height: 1),
              _ProfileFieldTile(
                  label: context.tr("account_title"),
                  value: displayAccountTitle),
            ],
          ),
          const SizedBox(height: 14),

          // ── Nominee card ────────────────────────────────────────────
          _ProfileCard(
            title: context.tr("nominee_short"),
            icon: Icons.people_outline_rounded,
            trailingAction: TextButton.icon(
              onPressed: _openNomineeEditDialog,
              icon: const Icon(Icons.edit_rounded, size: 14),
              label: Text(context.tr("edit_short"),
                  style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
            children: [
              _ProfileFieldTile(
                  label: context.tr("nominee_name"),
                  value: displayNomineeName),
              const Divider(height: 1),
              _ProfileFieldTile(
                  label: context.tr("nominee_cnic"),
                  value: displayNomineeCnic),
              const Divider(height: 1),
              _ProfileFieldTile(
                  label: context.tr("relationship"),
                  value: displayNomineeRelation),
            ],
          ),
          const SizedBox(height: 14),
          if (kycRecord != null) ...[
            _ProfileCard(
              title: context.tr("profile_verification_details"),
              icon: Icons.verified_user_outlined,
              children: [
                if (kycRecord.address != null &&
                    kycRecord.address!.trim().isNotEmpty) ...[
                  _ProfileFieldTile(
                    label: context.tr("kyc_address"),
                    value: kycRecord.address,
                  ),
                  const Divider(height: 1),
                ],
                _ProfileFieldTile(
                  label: context.tr("profile_submission_status"),
                  value: _kycLifecycleBadgeLabel(context, kycRecord.status),
                  locked: true,
                ),
                if (kycRecord.status == KycLifecycleStatus.rejected &&
                    kycRecord.rejectionReason != null &&
                    kycRecord.rejectionReason!.trim().isNotEmpty) ...[
                  const Divider(height: 1),
                  _ProfileFieldTile(
                    label: context.tr("kyc_rejection_reason_prefix"),
                    value: kycRecord.rejectionReason,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (hasPasswordProvider) ...[
            _ProfileCard(
              title: context.tr("profile_account_security"),
              icon: Icons.lock_outline_rounded,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openChangePasswordDialog,
                      icon: const Icon(Icons.vpn_key_outlined, size: 18),
                      label: Text(context.tr("change_password_btn")),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
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
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 15, color: AppColors.bodyMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr("profile_changes_note"),
                    style: const TextStyle(
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
                  profile.name.isNotEmpty ? profile.name : context.tr("investor_label"),
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
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
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
      textAlignVertical: TextAlignVertical.center,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.heading,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: AppColors.surfaceMuted,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}

// ── Change password dialog ─────────────────────────────────────────────────────

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _localError;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  InputDecoration _passwordFieldDecoration(
    BuildContext context, {
    required String labelText,
    required bool obscure,
    required VoidCallback onToggleVisibility,
  }) {
    return InputDecoration(
      labelText: labelText,
      border: const OutlineInputBorder(),
      isDense: true,
      suffixIcon: IconButton(
        tooltip: obscure
            ? context.tr("password_visibility_show")
            : context.tr("password_visibility_hide"),
        icon: Icon(
          obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
        ),
        onPressed: onToggleVisibility,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(passwordChangeProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    FocusScope.of(context).unfocus();
    if (_new.text != _confirm.text) {
      setState(() => _localError = context.tr("passwords_do_not_match"));
      return;
    }
    if (_new.text.length < 6) {
      setState(() => _localError = context.tr("password_min_chars"));
      return;
    }
    await ref.read(passwordChangeProvider.notifier).changePassword(
          currentPassword: _current.text,
          newPassword: _new.text,
        );
    if (!mounted) return;
    final asyncState = ref.read(passwordChangeProvider);
    asyncState.whenOrNull(
      data: (_) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.tr("password_changed_success")),
            backgroundColor: AppColors.success,
          ),
        );
      },
      error: (e, _) {
        setState(() {
          _localError = e.toString().replaceFirst("Exception: ", "");
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(passwordChangeProvider).isLoading;

    return AlertDialog(
      title: Text(context.tr("change_password_title")),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_localError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _localError!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              TextField(
                controller: _current,
                obscureText: _obscureCurrent,
                decoration: _passwordFieldDecoration(
                  context,
                  labelText: context.tr("current_password_label"),
                  obscure: _obscureCurrent,
                  onToggleVisibility: () => setState(
                    () => _obscureCurrent = !_obscureCurrent,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _new,
                obscureText: _obscureNew,
                decoration: _passwordFieldDecoration(
                  context,
                  labelText: context.tr("new_password_label"),
                  obscure: _obscureNew,
                  onToggleVisibility: () =>
                      setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                obscureText: _obscureConfirm,
                decoration: _passwordFieldDecoration(
                  context,
                  labelText: context.tr("confirm_password_label"),
                  obscure: _obscureConfirm,
                  onToggleVisibility: () => setState(
                    () => _obscureConfirm = !_obscureConfirm,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.of(context).pop(),
          child: Text(context.tr("cancel")),
        ),
        FilledButton(
          onPressed: loading ? null : _submit,
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr("change_password_btn")),
        ),
      ],
    );
  }
}
