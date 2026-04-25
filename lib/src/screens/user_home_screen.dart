import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../core/i18n/app_translations.dart";
import "../core/branding/brand_assets.dart";
import "../core/theme/app_colors.dart";
import "../core/compliance/risk_disclaimer_prefs.dart";
import "../core/widgets/app_bar_actions.dart";
import "../core/widgets/app_error_dialog.dart";
import "../core/widgets/mandatory_risk_disclaimer_strip.dart";
import "../features/investment/data/allocation_money_market.dart";
import "../features/update/data/app_update_providers.dart";
import "../features/update/presentation/update_action.dart";
import "../models/app_user.dart";
import "../providers/auth_providers.dart";
import "../providers/wallet_providers.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);

/// Dashboard wallet card only: mask PKR amounts when [hide] is true.
String _dashboardMoneyDisplay(bool hide, String formattedIfVisible) {
  if (hide) return "PKR ••••••";
  return formattedIfVisible;
}

Color _actionButtonBg(BuildContext context, Color lightTint) {
  if (Theme.of(context).brightness == Brightness.dark) {
    return Color.alphaBlend(
      lightTint.withValues(alpha: 0.55),
      Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
  return lightTint;
}

Color _quickAccessTileBg(BuildContext context, Color base) {
  if (Theme.of(context).brightness == Brightness.dark) {
    return Color.lerp(base, Colors.black, 0.30)!;
  }
  return base;
}

/// Dashboard page background: light uses brand tints; dark uses [ColorScheme] surfaces.
Color _dashboardBackgroundTop(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  if (Theme.of(context).brightness == Brightness.dark) {
    return scheme.surface;
  }
  return AppColors.backgroundTop;
}

List<Color> _dashboardBackgroundGradient(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  if (Theme.of(context).brightness == Brightness.dark) {
    return [scheme.surface, scheme.surfaceContainerLowest];
  }
  return [AppColors.backgroundTop, AppColors.backgroundBottom];
}

class UserHomeScreen extends ConsumerWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final scheme = Theme.of(context).colorScheme;

    return profileAsync.when(
      loading: () => Scaffold(
        backgroundColor: scheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: scheme.surface,
        body: Center(child: Text("${context.tr("error_prefix")} $e")),
      ),
      data: (profile) {
        if (profile == null) {
          return Scaffold(
            backgroundColor: scheme.surface,
            body: Center(child: Text(context.tr("profile_not_found"))),
          );
        }
        return _DashboardView(profile: profile);
      },
    );
  }
}

class _DashboardView extends ConsumerStatefulWidget {
  const _DashboardView({required this.profile});
  final AppUser profile;

  @override
  ConsumerState<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<_DashboardView> {
  bool _scheduledOneTimeDisclaimer = false;
  bool _hideMoney = true;

  Future<void> _maybeShowOneTimeRiskDisclaimer() async {
    if (await hasSeenRiskDisclaimer()) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr("mandatory_disclaimer_heading")),
        content: const SingleChildScrollView(
          child: MandatoryRiskDisclaimerStrip(),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await markRiskDisclaimerSeen();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(context.tr("continue_btn")),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_scheduledOneTimeDisclaimer) {
      _scheduledOneTimeDisclaimer = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowOneTimeRiskDisclaimer();
      });
    }

    final walletAsync = ref.watch(userWalletStreamProvider);
    final bgGradient = _dashboardBackgroundGradient(context);

    return Scaffold(
      backgroundColor: _dashboardBackgroundTop(context),
      drawer: _AppDrawer(profile: widget.profile),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: bgGradient,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            _DashboardAppBar(profile: widget.profile),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _KycBanner(profile: widget.profile),
                  const SizedBox(height: 20),
                  walletAsync.when(
                    loading: () => const _WalletCardSkeleton(),
                    error: (e, _) => _WalletCard(
                      wallet: null,
                      hideMoney: _hideMoney,
                      onToggleHideMoney: () =>
                          setState(() => _hideMoney = !_hideMoney),
                    ),
                    data: (w) => _WalletCard(
                      wallet: w,
                      hideMoney: _hideMoney,
                      onToggleHideMoney: () =>
                          setState(() => _hideMoney = !_hideMoney),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel(label: context.tr("quick_actions")),
                  const SizedBox(height: 12),
                  _QuickActions(profile: widget.profile),
                  const SizedBox(height: 28),
                  _SectionLabel(
                    label: context.tr("quick_access"),
                    smallCaps: true,
                  ),
                  const SizedBox(height: 12),
                  const _QuickAccessGrid(),
                  const SizedBox(height: 28),
                  _SectionLabel(
                    label: context.tr("dashboard_more"),
                    smallCaps: true,
                  ),
                  const SizedBox(height: 12),
                  _NavTile(
                    icon: Icons.shield_outlined,
                    label: context.tr("nav_kyc"),
                    subtitle: _kycSubtitle(context, widget.profile.kycStatus),
                    badge: _kycBadge(context, widget.profile.kycStatus),
                    onTap: () => context.push("/kyc"),
                  ),
                  const SizedBox(height: 10),
                  _NavTile(
                    icon: Icons.bar_chart_rounded,
                    label: context.tr("nav_reports"),
                    subtitle: context.tr("nav_reports_subtitle"),
                    onTap: () => context.push("/reports"),
                  ),
                  const SizedBox(height: 10),
                  _NavTile(
                    icon: Icons.notifications_outlined,
                    label: context.tr("notifications"),
                    subtitle: context.tr("notifications_subtitle"),
                    onTap: () => context.push("/notifications"),
                  ),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _kycSubtitle(BuildContext context, KycLifecycleStatus s) =>
      switch (s) {
        KycLifecycleStatus.approved => context.tr("kyc_subtitle_approved"),
        KycLifecycleStatus.underReview => context.tr(
          "kyc_subtitle_under_review",
        ),
        KycLifecycleStatus.rejected => context.tr("kyc_subtitle_rejected"),
        KycLifecycleStatus.pending => context.tr("kyc_subtitle_pending"),
      };

  _KycBadgeData? _kycBadge(BuildContext context, KycLifecycleStatus s) =>
      switch (s) {
        KycLifecycleStatus.approved => _KycBadgeData(
          label: context.tr("kyc_badge_verified"),
          color: AppColors.success,
        ),
        KycLifecycleStatus.underReview => _KycBadgeData(
          label: context.tr("kyc_badge_in_review"),
          color: Colors.blue.shade700,
        ),
        KycLifecycleStatus.rejected => _KycBadgeData(
          label: context.tr("kyc_badge_rejected"),
          color: AppColors.error,
        ),
        KycLifecycleStatus.pending => _KycBadgeData(
          label: context.tr("kyc_badge_pending"),
          color: AppColors.warning,
        ),
      };
}

// ─── App bar ────────────────────────────────────────────────────────────────

class _DashboardAppBar extends ConsumerWidget {
  const _DashboardAppBar({required this.profile});
  final AppUser profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;
    return SliverAppBar(
      expandedHeight: 0,
      pinned: true,
      backgroundColor: _dashboardBackgroundTop(context),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0.5,
      elevation: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: Icon(Icons.menu_rounded, color: onSurface),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr("good_day"),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: muted,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            profile.name.isNotEmpty
                ? profile.name
                : context.tr("investor_label"),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              color: onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: const [AppBarPreferenceActions(), SizedBox(width: 8)],
    );
  }
}

// ─── Drawer ─────────────────────────────────────────────────────────────────

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer({required this.profile});
  final AppUser profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final updateGate = ref.watch(stableAppUpdateGateProvider).valueOrNull;
    final showUpdateItem = updateGate?.showGraceBanner == true;
    final initials = profile.name.isNotEmpty
        ? profile.name
              .trim()
              .split(" ")
              .map((w) => w[0].toUpperCase())
              .take(2)
              .join()
        : "?";

    return Drawer(
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    BrandAssets.logoPng,
                    height: 44,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 16),
                  CircleAvatar(
                    radius: 28,
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
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 2),
                  Text(
                    profile.email,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  _KycChip(status: profile.kycStatus),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.dashboard_outlined,
                    label: context.tr("drawer_dashboard"),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.person_outline_rounded,
                    label: context.tr("qa_my_profile"),
                    onTap: () {
                      Navigator.pop(context);
                      context.push("/profile");
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.verified_user_outlined,
                    label: context.tr("drawer_transparency"),
                    onTap: () {
                      Navigator.pop(context);
                      context.push("/transparency");
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.pie_chart,
                    label: context.tr("drawer_portfolio"),
                    onTap: () {
                      Navigator.pop(context);
                      context.push("/portfolio");
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.trending_up_rounded,
                    label: context.tr("drawer_live_profit"),
                    onTap: () {
                      Navigator.pop(context);
                      context.push("/profit-live");
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.show_chart_rounded,
                    label: context.tr("drawer_kmi30_companies"),
                    onTap: () {
                      Navigator.pop(context);
                      context.push("/market/kmi30-companies");
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: context.tr("drawer_wallet"),
                    onTap: () {
                      Navigator.pop(context);
                      context.push("/wallet-ledger");
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.shield_outlined,
                    label: context.tr("drawer_kyc"),
                    onTap: () {
                      Navigator.pop(context);
                      context.push("/kyc");
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.bar_chart_rounded,
                    label: context.tr("drawer_reports"),
                    onTap: () {
                      Navigator.pop(context);
                      context.push("/reports");
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.notifications_outlined,
                    label: context.tr("drawer_notifications"),
                    onTap: () {
                      Navigator.pop(context);
                      context.push("/notifications");
                    },
                  ),
                  if (showUpdateItem)
                    _DrawerItem(
                      icon: Icons.system_update_alt_rounded,
                      label: context.tr("update_now"),
                      onTap: () async {
                        Navigator.pop(context);
                        final release = updateGate!.release!;
                        await openReleaseUpdate(context, ref, release);
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            _DrawerItem(
              icon: Icons.logout_rounded,
              label: context.tr("drawer_logout"),
              iconColor: AppColors.error,
              labelColor: AppColors.error,
              onTap: () async {
                Navigator.pop(context);
                try {
                  await ref.read(authControllerProvider.notifier).logout();
                  if (context.mounted) context.go("/login");
                } catch (e) {
                  if (context.mounted) await showAppErrorDialog(context, e);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: iconColor ?? scheme.primary, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: labelColor ?? scheme.onSurface,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
      horizontalTitleGap: 8,
      dense: true,
    );
  }
}

class _KycChip extends StatelessWidget {
  const _KycChip({required this.status});
  final KycLifecycleStatus status;

  @override
  Widget build(BuildContext context) {
    final (labelKey, color) = switch (status) {
      KycLifecycleStatus.approved => ("kyc_chip_verified", AppColors.success),
      KycLifecycleStatus.underReview => (
        "kyc_chip_under_review",
        Colors.blue.shade600,
      ),
      KycLifecycleStatus.rejected => ("kyc_chip_rejected", AppColors.error),
      KycLifecycleStatus.pending => ("kyc_chip_pending", AppColors.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 5),
          Text(
            context.tr(labelKey),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── KYC banner ─────────────────────────────────────────────────────────────

class _KycBanner extends StatelessWidget {
  const _KycBanner({required this.profile});
  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    if (profile.kycStatus == KycLifecycleStatus.approved) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (
      Color bg,
      Color fg,
      IconData icon,
      String titleKey,
      String subtitleKey,
    ) = switch (profile.kycStatus) {
      KycLifecycleStatus.pending => (
        isDark
            ? scheme.secondaryContainer.withValues(alpha: 0.35)
            : const Color(0xFFFFF8E1),
        AppColors.warning,
        Icons.info_outline_rounded,
        "kyc_banner_pending_title",
        "kyc_banner_pending_subtitle",
      ),
      KycLifecycleStatus.underReview => (
        isDark
            ? scheme.primaryContainer.withValues(alpha: 0.4)
            : const Color(0xFFE3F2FD),
        Colors.blue.shade700,
        Icons.hourglass_top_rounded,
        "kyc_banner_review_title",
        "kyc_banner_review_subtitle",
      ),
      KycLifecycleStatus.rejected => (
        isDark
            ? scheme.errorContainer.withValues(alpha: 0.45)
            : const Color(0xFFFFEBEE),
        AppColors.error,
        Icons.warning_amber_rounded,
        "kyc_banner_rejected_title",
        "kyc_banner_rejected_subtitle",
      ),
      KycLifecycleStatus.approved => (
        Colors.transparent,
        Colors.transparent,
        Icons.check,
        "",
        "",
      ),
    };

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(titleKey),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: fg,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr(subtitleKey),
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
                if (profile.kycStatus != KycLifecycleStatus.underReview) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => context.push("/kyc"),
                    child: Text(
                      profile.kycStatus == KycLifecycleStatus.rejected
                          ? context.tr("kyc_cta_resubmit")
                          : context.tr("kyc_cta_start"),
                      style: TextStyle(
                        color: fg,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Wallet hero card ────────────────────────────────────────────────────────

class _WalletCard extends ConsumerWidget {
  const _WalletCard({
    required this.wallet,
    required this.hideMoney,
    required this.onToggleHideMoney,
  });
  final Map<String, dynamic>? wallet;
  final bool hideMoney;
  final VoidCallback onToggleHideMoney;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allocationTotalPkr = wallet == null
        ? 0.0
        : ((wallet!["availableBalance"] as num?)?.toDouble() ??
              (wallet!["currentBalance"] as num?)?.toDouble() ??
              0);
    final moneyMarketPkr = moneyMarketAmountFromAllocationTotal(
      allocationTotalPkr,
    );
    final avail = (wallet?["availableBalance"] as num?)?.toDouble() ?? 0;
    final reserved = (wallet?["reservedAmount"] as num?)?.toDouble() ?? 0;
    final td = (wallet?["totalDeposited"] as num?)?.toDouble() ?? 0;
    final tp = (wallet?["totalProfit"] as num?)?.toDouble() ?? 0;
    final dash = context.tr("em_dash");

    final depositedLabel = context
        .tr("totals_line_deposited")
        .replaceAll(":", "")
        .trim();

    final totalAllocationDisplay = wallet == null
        ? dash
        : _dashboardMoneyDisplay(hideMoney, _money.format(allocationTotalPkr));

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.26 : 0.35),
            blurRadius: isDark ? 16 : 18,
            offset: Offset(0, isDark ? 4 : 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          clipBehavior: Clip.antiAlias,
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -56,
              top: -48,
              child: IgnorePointer(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.walletHeroOverlayA,
                  ),
                ),
              ),
            ),
            Positioned(
              left: -40,
              bottom: -36,
              child: IgnorePointer(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.walletHeroOverlayB,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr("money_market_withdrawable_label"),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        tooltip: hideMoney
                            ? context.tr("show_amounts")
                            : context.tr("hide_amounts"),
                        icon: Icon(
                          hideMoney
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Colors.white70,
                          size: 22,
                        ),
                        onPressed: onToggleHideMoney,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.30 : 0.22,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF69F0AE),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              context.tr("live_badge"),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    wallet == null
                        ? dash
                        : _dashboardMoneyDisplay(
                            hideMoney,
                            _money.format(moneyMarketPkr),
                          ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${context.tr("total_investment_label")}: "
                    "$totalAllocationDisplay",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _WalletStat(
                          label: context.tr("available"),
                          value: wallet == null
                              ? dash
                              : _dashboardMoneyDisplay(
                                  hideMoney,
                                  _money.format(avail),
                                ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withValues(
                          alpha: isDark ? 0.28 : 0.2,
                        ),
                      ),
                      Expanded(
                        child: _WalletStat(
                          label: context.tr("reserved"),
                          value: wallet == null
                              ? dash
                              : _dashboardMoneyDisplay(
                                  hideMoney,
                                  _money.format(reserved),
                                ),
                          align: TextAlign.center,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withValues(
                          alpha: isDark ? 0.28 : 0.2,
                        ),
                      ),
                      Expanded(
                        child: _WalletStat(
                          label: depositedLabel,
                          value: wallet == null
                              ? dash
                              : _dashboardMoneyDisplay(
                                  hideMoney,
                                  _money.format(td),
                                ),
                          align: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: isDark ? 0.22 : 0.15),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.trending_up_rounded,
                        size: 15,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "${context.tr("profit_label")}: "
                          "${wallet == null ? dash : _dashboardMoneyDisplay(hideMoney, _money.format(tp))}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletStat extends StatelessWidget {
  const _WalletStat({required this.label, required this.value, this.align});
  final String label;
  final String value;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: align == TextAlign.right
            ? CrossAxisAlignment.end
            : align == TextAlign.center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            textAlign: align,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            textAlign: align,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletCardSkeleton extends StatelessWidget {
  const _WalletCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
      ),
    );
  }
}

// ─── Quick actions ───────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.profile});
  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    final approved = profile.kycStatus == KycLifecycleStatus.approved;
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.add_rounded,
            label: context.tr("deposit"),
            enabled: approved,
            backgroundColor: AppColors.dashboardDepositTint,
            foregroundColor: AppColors.dashboardDepositFg,
            onTap: () => context.push("/wallet-ledger/deposit"),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.remove_rounded,
            label: context.tr("withdraw"),
            enabled: approved,
            backgroundColor: AppColors.dashboardWithdrawTint,
            foregroundColor: AppColors.dashboardWithdrawFg,
            onTap: () => context.push("/wallet-ledger/withdraw"),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.history_rounded,
            label: context.tr("history"),
            backgroundColor: AppColors.dashboardHistoryTint,
            foregroundColor: AppColors.dashboardHistoryFg,
            onTap: () => context.push("/wallet-ledger?tab=history"),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.bar_chart_rounded,
            label: context.tr("reports_quick"),
            backgroundColor: AppColors.dashboardReportsTint,
            foregroundColor: AppColors.dashboardReportsFg,
            onTap: () => context.push("/reports"),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
    this.enabled = true,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = enabled
        ? _actionButtonBg(context, backgroundColor)
        : scheme.surfaceContainerHighest;
    final fg = enabled ? foregroundColor : scheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled
                  ? (isDark
                        ? fg.withValues(alpha: 0.34)
                        : fg.withValues(alpha: 0.12))
                  : scheme.outline.withValues(alpha: 0.4),
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.24 : 0.04,
                      ),
                      blurRadius: isDark ? 10 : 8,
                      offset: Offset(0, isDark ? 3 : 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: fg),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quick access grid ────────────────────────────────────────────────────────

class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.22,
      children: [
        _QuickAccessTile(
          label: context.tr("qa_portfolio"),
          icon: Icons.pie_chart_outline_rounded,
          watermark: Icons.pie_chart_rounded,
          backgroundColor: _quickAccessTileBg(
            context,
            AppColors.quickAccessPortfolio,
          ),
          onTap: () => context.push("/portfolio"),
        ),
        _QuickAccessTile(
          label: context.tr("qa_wallet"),
          icon: Icons.account_balance_wallet_rounded,
          watermark: Icons.account_balance_wallet_outlined,
          backgroundColor: _quickAccessTileBg(
            context,
            AppColors.quickAccessWallet,
          ),
          onTap: () => context.push("/wallet-ledger?tab=wallet"),
        ),
        _QuickAccessTile(
          label: context.tr("qa_transactions"),
          icon: Icons.swap_horiz_rounded,
          watermark: Icons.receipt_long_rounded,
          backgroundColor: _quickAccessTileBg(
            context,
            AppColors.quickAccessTransactions,
          ),
          onTap: () => context.push("/wallet-ledger?tab=transactions"),
        ),
        _QuickAccessTile(
          label: context.tr("qa_my_profile"),
          icon: Icons.person_rounded,
          watermark: Icons.person_outline_rounded,
          backgroundColor: _quickAccessTileBg(
            context,
            AppColors.quickAccessProfile,
          ),
          onTap: () => context.push("/profile"),
        ),
      ],
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.label,
    required this.icon,
    required this.watermark,
    required this.backgroundColor,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final IconData watermark;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? scheme.outlineVariant.withValues(alpha: 0.42)
                  : Colors.transparent,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.08),
                blurRadius: isDark ? 14 : 12,
                offset: Offset(0, isDark ? 5 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              clipBehavior: Clip.antiAlias,
              children: [
                Positioned(
                  right: -8,
                  bottom: -12,
                  child: Icon(
                    watermark,
                    size: 96,
                    color: Colors.white.withValues(alpha: isDark ? 0.13 : 0.1),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: isDark ? 0.26 : 0.22,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: Colors.white, size: 22),
                        ),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Section label ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.smallCaps = false});
  final String label;
  final bool smallCaps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      smallCaps ? label.toUpperCase() : label,
      style: TextStyle(
        fontSize: smallCaps ? 11 : 13,
        fontWeight: FontWeight.w700,
        color: scheme.onSurfaceVariant,
        letterSpacing: smallCaps ? 1.1 : 0.4,
      ),
    );
  }
}

// ─── Nav tile ────────────────────────────────────────────────────────────────

class _KycBadgeData {
  const _KycBadgeData({required this.label, required this.color});
  final String label;
  final Color color;
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final _KycBadgeData? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: isDark ? 0.98 : 1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.72 : 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.04),
              blurRadius: isDark ? 12 : 10,
              offset: Offset(0, isDark ? 4 : 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: scheme.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badge!.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            badge!.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: badge!.color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
