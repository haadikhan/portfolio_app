import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/i18n/language_provider.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/theme/theme_provider.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../models/app_user.dart";
import "../../../providers/auth_providers.dart";
import "../../../providers/biometric_providers.dart";
import "../../../providers/mpin_providers.dart";
import "../../../providers/profile_providers.dart";
import "../../mpin/data/mpin_service.dart";
import "../../mpin/data/mpin_status.dart";
import "../../mpin/presentation/mpin_keypad.dart";
import "../../mpin/presentation/mpin_setup_screen.dart";
import "../../security/presentation/security_settings_section.dart";
import "../../service_requests/presentation/submit_change_request_screen.dart";
import "../../service_requests/providers/change_request_providers.dart";

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
          child: Text(
            "${context.tr("error_prefix")} $e",
            style: const TextStyle(color: AppColors.error),
          ),
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
  Widget _pendingBadgeChip(BuildContext context) {
    return Tooltip(
      message: context.tr("sr_field_locked_hint"),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 14, color: AppColors.warning),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                context.tr("sr_pending_badge"),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB45309),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestChangeTrailing({
    required BuildContext context,
    required bool hasPending,
    required VoidCallback? onPressed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasPending) ...[
          Flexible(child: _pendingBadgeChip(context)),
          const SizedBox(width: 8),
        ],
        OutlinedButton(
          onPressed: hasPending ? null : onPressed,
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          child: Text(
            context.tr("sr_request_change"),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Future<void> _openSubmitProfile() async {
    final pending = ref.read(pendingChangeRequestsProvider);
    if (hasPendingForType(pending, "profile")) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => SubmitChangeRequestScreen(
          requestType: "profile",
          currentValues: {
            ctx.tr("full_name"): widget.profile.name,
          },
          editableLabels: [
            (key: "name", label: ctx.tr("full_name")),
          ],
        ),
      ),
    );
  }

  Future<void> _openSubmitPhone(String displayPhone) async {
    final pending = ref.read(pendingChangeRequestsProvider);
    if (hasPendingForType(pending, "phone")) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => SubmitChangeRequestScreen(
          requestType: "phone",
          currentValues: {
            ctx.tr("profile_phone_number"): displayPhone,
          },
          editableLabels: [
            (key: "phone", label: ctx.tr("profile_phone_number")),
          ],
        ),
      ),
    );
  }

  Future<void> _openSubmitBank({
    required String bankName,
    required String accountNumber,
    required String accountTitle,
  }) async {
    final pending = ref.read(pendingChangeRequestsProvider);
    if (hasPendingForType(pending, "bank")) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => SubmitChangeRequestScreen(
          requestType: "bank",
          currentValues: {
            ctx.tr("bank_name"): bankName,
            ctx.tr("account_number"): accountNumber,
            ctx.tr("account_title"): accountTitle,
          },
          editableLabels: [
            (key: "bankName", label: ctx.tr("bank_name")),
            (key: "accountNumber", label: ctx.tr("account_number")),
            (key: "accountTitle", label: ctx.tr("account_title")),
          ],
        ),
      ),
    );
  }

  Future<void> _openSubmitNominee({
    required String nomineeName,
    required String nomineeCnic,
    required String nomineeRelation,
  }) async {
    final pending = ref.read(pendingChangeRequestsProvider);
    if (hasPendingForType(pending, "nominee")) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => SubmitChangeRequestScreen(
          requestType: "nominee",
          currentValues: {
            ctx.tr("nominee_name"): nomineeName,
            ctx.tr("nominee_cnic"): nomineeCnic,
            ctx.tr("relationship"): nomineeRelation,
          },
          editableLabels: [
            (key: "nomineeName", label: ctx.tr("nominee_name")),
            (key: "nomineeCnic", label: ctx.tr("nominee_cnic")),
            (key: "nomineeRelation", label: ctx.tr("relationship")),
          ],
        ),
      ),
    );
  }

  void _openChangePasswordDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => const _ChangePasswordDialog(),
    );
  }

  Future<String?> _promptMpin({required String title, String? subtitle}) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _MpinCurrentPinDialog(title: title, subtitle: subtitle),
    );
  }

  Future<void> _openMpinSetup() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const MpinSetupScreen(mode: MpinSetupMode.setup),
      ),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr("mpin_set_success")),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _openMpinChange() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const MpinSetupScreen(mode: MpinSetupMode.change),
      ),
    );
  }

  Future<void> _toggleMpinEnabled(bool desired) async {
    final pin = await _promptMpin(
      title: context.tr("mpin_toggle_currentpin_title"),
      subtitle: context.tr("mpin_toggle_currentpin_body"),
    );
    if (pin == null || !mounted) return;
    try {
      await ref
          .read(mpinServiceProvider)
          .setMpinEnabled(enabled: desired, currentPin: pin);
    } on MpinException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_describeMpinError(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _removeMpin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr("mpin_remove_confirm_title")),
        content: Text(context.tr("mpin_remove_confirm_body")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr("cancel")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr("mpin_remove_cta")),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final pin = await _promptMpin(title: context.tr("mpin_enter_current"));
    if (pin == null || !mounted) return;
    try {
      await ref.read(mpinServiceProvider).clearMpin(currentPin: pin);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr("mpin_cleared_success")),
          backgroundColor: AppColors.success,
        ),
      );
    } on MpinException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_describeMpinError(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Forgot MPIN flow: re-authenticate with the current Firebase Auth password
  /// to refresh `auth_time`, then push the setup screen. The backend's
  /// `setMpin` accepts a missing `currentPin` only when `auth_time` is fresh.
  Future<void> _forgotMpin() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr("mpin_reauth_failed")),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _ReauthPasswordDialog(),
    );
    if (password == null || password.isEmpty || !mounted) return;
    try {
      final cred = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr("mpin_reauth_failed")),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (!mounted) return;
    await _openMpinSetup();
  }

  String _describeMpinError(MpinException e) {
    switch (e.kind) {
      case MpinErrorKind.wrong:
        return context.tr("mpin_wrong");
      case MpinErrorKind.locked:
        return context.tr("mpin_locked_short");
      case MpinErrorKind.invalidFormat:
        return context.tr("mpin_invalid_format");
      case MpinErrorKind.needsCurrentPin:
        return context.tr("mpin_enter_current");
      case MpinErrorKind.notSet:
      case MpinErrorKind.unauthenticated:
      case MpinErrorKind.generic:
        return e.message ?? e.code ?? context.tr("error_alert_title");
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pending = ref.watch(pendingChangeRequestsProvider);
    final pendingTicketCount = pending.length;
    final hasPendingProfile = hasPendingForType(pending, "profile");
    final hasPendingPhone = hasPendingForType(pending, "phone");
    final hasPendingBank = hasPendingForType(pending, "bank");
    final hasPendingNominee = hasPendingForType(pending, "nominee");
    final kycAsync = ref.watch(userKycProvider);
    final kycRecord = kycAsync.valueOrNull;
    final displayPhone = _preferProfileThenKyc(
      widget.profile.phone,
      kycRecord?.phone,
    );
    final displayCnic = _preferProfileThenKyc(
      widget.profile.cnic,
      kycRecord?.cnicNumber,
    );
    final displayBankName = _preferProfileThenKyc(
      widget.profile.bankName,
      kycRecord?.bankName,
    );
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
    final hasPasswordProvider =
        FirebaseAuth.instance.currentUser?.providerData.any(
          (p) => p.providerId == "password",
        ) ??
        false;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Profile header ─────────────────────────────────────────
          _ProfileHeader(profile: widget.profile),
          const SizedBox(height: 20),

          // ── Personal info card ──────────────────────────────────────
          _ProfileCard(
            title: context.tr("personal_information"),
            icon: Icons.person_outline_rounded,
            useAdaptiveColors: true,
            children: [
              _ProfileFieldTile(
                label: context.tr("email_address"),
                value: widget.profile.email.isNotEmpty
                    ? widget.profile.email
                    : null,
                locked: true,
                useAdaptiveColors: true,
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              _ProfileFieldTile(
                label: context.tr("full_name"),
                value: widget.profile.name.isNotEmpty
                    ? widget.profile.name
                    : null,
                useAdaptiveColors: true,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _requestChangeTrailing(
                    context: context,
                    hasPending: hasPendingProfile,
                    onPressed: _openSubmitProfile,
                  ),
                ),
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              _ProfileFieldTile(
                label: context.tr("profile_phone_number"),
                value: displayPhone,
                useAdaptiveColors: true,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _requestChangeTrailing(
                    context: context,
                    hasPending: hasPendingPhone,
                    onPressed: () =>
                        _openSubmitPhone(displayPhone ?? ""),
                  ),
                ),
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              _ProfileFieldTile(
                label: context.tr("cnic_label"),
                value: displayCnic,
                locked: true,
                useAdaptiveColors: true,
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              _ProfileFieldTile(
                label: context.tr("profile_kyc_status_label"),
                value: _kycLifecycleBadgeLabel(
                  context,
                  widget.profile.kycStatus,
                ),
                locked: true,
                useAdaptiveColors: true,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Service requests entry ───────────────────────────────────
          Material(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(
                Icons.assignment_outlined,
                color: scheme.primary,
              ),
              title: Text(context.tr("service_requests_nav_tile")),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pendingTicketCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          "$pendingTicketCount",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              onTap: () => context.push("/profile/service-requests"),
            ),
          ),
          const SizedBox(height: 14),

          const SecuritySettingsSection(),
          const SizedBox(height: 14),

          // ── Bank details card ───────────────────────────────────────
          _ProfileCard(
            title: context.tr("bank_details_section"),
            icon: Icons.account_balance_outlined,
            trailingAction: _requestChangeTrailing(
              context: context,
              hasPending: hasPendingBank,
              onPressed: () => _openSubmitBank(
                bankName: displayBankName ?? "",
                accountNumber: displayAccountNumber ?? "",
                accountTitle: displayAccountTitle ?? "",
              ),
            ),
            children: [
              _ProfileFieldTile(
                label: context.tr("bank_name"),
                value: displayBankName,
              ),
              const Divider(height: 1),
              _ProfileFieldTile(
                label: context.tr("account_number"),
                value: displayAccountNumber,
              ),
              const Divider(height: 1),
              _ProfileFieldTile(
                label: context.tr("account_title"),
                value: displayAccountTitle,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Nominee card ────────────────────────────────────────────
          _ProfileCard(
            title: context.tr("nominee_short"),
            icon: Icons.people_outline_rounded,
            trailingAction: _requestChangeTrailing(
              context: context,
              hasPending: hasPendingNominee,
              onPressed: () => _openSubmitNominee(
                nomineeName: displayNomineeName ?? "",
                nomineeCnic: displayNomineeCnic ?? "",
                nomineeRelation: displayNomineeRelation ?? "",
              ),
            ),
            children: [
              _ProfileFieldTile(
                label: context.tr("nominee_name"),
                value: displayNomineeName,
              ),
              const Divider(height: 1),
              _ProfileFieldTile(
                label: context.tr("nominee_cnic"),
                value: displayNomineeCnic,
              ),
              const Divider(height: 1),
              _ProfileFieldTile(
                label: context.tr("relationship"),
                value: displayNomineeRelation,
              ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openChangePasswordDialog,
                      icon: const Icon(Icons.vpn_key_outlined, size: 18),
                      label: Text(context.tr("change_password_btn")),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          _MpinSecurityCard(
            onSetup: _openMpinSetup,
            onChange: _openMpinChange,
            onToggleEnabled: _toggleMpinEnabled,
            onForgot: hasPasswordProvider ? _forgotMpin : null,
            onRemove: _removeMpin,
          ),
          const SizedBox(height: 14),
          _AppPreferencesCard(hasPasswordProvider: hasPasswordProvider),

          const SizedBox(height: 20),

          // ── Pending changes note ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr("profile_changes_note"),
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
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
  const _AppPreferencesCard({required this.hasPasswordProvider});

  final bool hasPasswordProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider).valueOrNull ?? ThemeMode.system;
    final locale =
        ref.watch(languageProvider).valueOrNull ?? const Locale("en");
    final isUrdu = locale.languageCode == "ur";
    final biometricEnabled =
        ref.watch(biometricEnabledProvider).valueOrNull ?? false;
    final biometricCapability = ref
        .watch(biometricCapabilityProvider)
        .valueOrNull;
    final biometricAvailable = biometricCapability?.isAvailable == true;

    return _ProfileCard(
      title: context.tr("app_preferences"),
      icon: Icons.tune_rounded,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr("theme_mode_label"),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: const Icon(Icons.light_mode_rounded, size: 16),
                    label: Text(context.tr("theme_mode_light")),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: const Icon(Icons.dark_mode_rounded, size: 16),
                    label: Text(context.tr("theme_mode_dark")),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: const Icon(Icons.brightness_auto_rounded, size: 16),
                    label: Text(context.tr("theme_mode_auto")),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (selected) {
                  ref
                      .read(themeProvider.notifier)
                      .setThemeMode(selected.first);
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              if (themeMode == ThemeMode.system) ...[
                const SizedBox(height: 6),
                Text(
                  context.tr("theme_mode_auto_subtitle"),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.language_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr("language"),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUrdu ? context.tr("urdu") : context.tr("english"),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
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
                onSelectionChanged: (v) =>
                    ref.read(languageProvider.notifier).setLanguage(v.first),
              ),
            ],
          ),
        ),
        if (hasPasswordProvider) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.fingerprint_rounded,
                  size: 18,
                  color: biometricAvailable
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr("biometric_login_label"),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        biometricAvailable
                            ? context.tr("biometric_login_enabled_hint")
                            : context.tr("fingerprint_not_setup"),
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: biometricEnabled,
                  onChanged: (v) async {
                    if (!v) {
                      await ref
                          .read(biometricControllerProvider.notifier)
                          .disable();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.tr("biometric_disabled_success"),
                          ),
                        ),
                      );
                      return;
                    }
                    final ok = await ref
                        .read(biometricControllerProvider.notifier)
                        .enableForCurrentUser();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? context.tr("biometric_enabled_success")
                              : context.tr("biometric_enable_failed"),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
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
                  profile.name.isNotEmpty
                      ? profile.name
                      : context.tr("investor_label"),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  profile.email,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
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
    this.useAdaptiveColors = true,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailingAction;
  final bool useAdaptiveColors;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: useAdaptiveColors
            ? scheme.surfaceContainerHighest
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: useAdaptiveColors
              ? scheme.outline.withValues(alpha: 0.15)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: useAdaptiveColors ? scheme.primary : AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: useAdaptiveColors
                        ? scheme.onSurface
                        : AppColors.heading,
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
          Divider(
            height: 1,
            color: useAdaptiveColors
                ? Theme.of(context).dividerColor
                : AppColors.border,
          ),
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
    this.useAdaptiveColors = true,
  });

  final String label;
  final String? value;
  final bool locked;
  final bool useAdaptiveColors;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayValue = (value != null && value!.isNotEmpty)
        ? value!
        : "Not added";
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
                  style: TextStyle(
                    fontSize: 11,
                    color: useAdaptiveColors
                        ? scheme.onSurfaceVariant
                        : AppColors.bodyMuted,
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
                        ? (useAdaptiveColors
                              ? scheme.onSurfaceVariant
                              : AppColors.bodyMuted)
                        : (useAdaptiveColors
                              ? scheme.onSurface
                              : AppColors.heading),
                    fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          if (locked)
            Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: useAdaptiveColors
                  ? scheme.onSurfaceVariant
                  : AppColors.bodyMuted,
            ),
        ],
      ),
    );
  }
}




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
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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
    await ref
        .read(passwordChangeProvider.notifier)
        .changePassword(currentPassword: _current.text, newPassword: _new.text);
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
                  onToggleVisibility: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
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
                  onToggleVisibility: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
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

class _MpinSecurityCard extends ConsumerWidget {
  const _MpinSecurityCard({
    required this.onSetup,
    required this.onChange,
    required this.onToggleEnabled,
    required this.onForgot,
    required this.onRemove,
  });

  final VoidCallback onSetup;
  final VoidCallback onChange;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback? onForgot;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final statusAsync = ref.watch(mpinStatusStreamProvider);
    final status = statusAsync.maybeWhen(
      data: (s) => s,
      orElse: () => MpinStatus.empty,
    );

    return _ProfileCard(
      title: context.tr("mpin_security_card_title"),
      icon: Icons.pin_outlined,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            context.tr("mpin_security_card_subtitle"),
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
        if (!status.hasMpin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSetup,
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: Text(context.tr("mpin_setup_cta")),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.primary,
                  side: BorderSide(color: scheme.primary),
                ),
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(context.tr("mpin_require_for_withdrawals")),
              subtitle: Text(
                context.tr("mpin_require_for_withdrawals_subtitle"),
                style: const TextStyle(fontSize: 11, height: 1.3),
              ),
              value: status.enabled,
              onChanged: onToggleEnabled,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onChange,
                    icon: const Icon(Icons.password_rounded, size: 18),
                    label: Text(context.tr("mpin_change_cta")),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.primary,
                      side: BorderSide(color: scheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(context.tr("mpin_remove_cta")),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onForgot != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: onForgot,
                  icon: const Icon(Icons.help_outline_rounded, size: 16),
                  label: Text(context.tr("mpin_forgot_cta")),
                ),
              ),
            ),
          if (status.lockedUntil != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  context.trParams("mpin_locked", {
                    "time": _formatTime(status.lockedUntil!),
                  }),
                  style: TextStyle(
                    color: scheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, "0");
    final m = t.minute.toString().padLeft(2, "0");
    return "$h:$m";
  }
}

/// Modal that asks for the *current* MPIN, used by toggle/remove flows where
/// the full setup screen would be overkill. Pops the entered PIN string or
/// `null` on cancel.
class _MpinCurrentPinDialog extends StatelessWidget {
  const _MpinCurrentPinDialog({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 18),
            MpinKeypad(
              headerText: context.tr("mpin_enter_current"),
              onCompleted: (pin) => Navigator.of(context).pop(pin),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(context.tr("cancel")),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reauth dialog used by the "Forgot MPIN" flow. Returns the entered password
/// string when the user proceeds, `null` on cancel. The actual
/// `reauthenticateWithCredential` call lives in [_ProfileBodyState].
class _ReauthPasswordDialog extends StatefulWidget {
  const _ReauthPasswordDialog();

  @override
  State<_ReauthPasswordDialog> createState() => _ReauthPasswordDialogState();
}

class _ReauthPasswordDialogState extends State<_ReauthPasswordDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr("mpin_reauth_title")),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr("mpin_reauth_subtitle"),
            style: const TextStyle(fontSize: 12, color: AppColors.bodyMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.tr("mpin_reauth_password_label"),
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(context.tr("cancel")),
        ),
        FilledButton(
          onPressed: () {
            final v = _ctrl.text;
            if (v.isEmpty) return;
            Navigator.of(context).pop(v);
          },
          child: Text(context.tr("continue_btn")),
        ),
      ],
    );
  }
}
