import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../core/theme/app_colors.dart";
import "../models/app_user.dart";
import "../providers/auth_providers.dart";
import "../providers/wallet_providers.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);

class UserHomeScreen extends ConsumerWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text("$e"))),
      data: (profile) {
        if (profile == null) {
          return const Scaffold(
            body: Center(child: Text("Profile not found.")),
          );
        }
        return _DashboardView(profile: profile);
      },
    );
  }
}

class _DashboardView extends ConsumerWidget {
  const _DashboardView({required this.profile});
  final AppUser profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(userWalletStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundTop,
      drawer: _AppDrawer(profile: profile),
      body: CustomScrollView(
        slivers: [
          _DashboardAppBar(profile: profile),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // KYC banner
                _KycBanner(profile: profile),

                // Wallet hero card
                const SizedBox(height: 20),
                walletAsync.when(
                  loading: () => const _WalletCardSkeleton(),
                  error: (e, _) => _WalletCard(wallet: null),
                  data: (w) => _WalletCard(wallet: w),
                ),

                // Quick actions
                const SizedBox(height: 24),
                _SectionLabel(label: "Quick actions"),
                const SizedBox(height: 12),
                _QuickActions(profile: profile),

                // Navigation tiles
                const SizedBox(height: 28),
                _SectionLabel(label: "My account"),
                const SizedBox(height: 12),
                _NavTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: "Wallet & ledger",
                  subtitle: "Balances, history, deposits & withdrawals",
                  onTap: () => context.push("/wallet-ledger"),
                ),
                const SizedBox(height: 10),
                _NavTile(
                  icon: Icons.shield_outlined,
                  label: "KYC verification",
                  subtitle: _kycSubtitle(profile.kycStatus),
                  badge: _kycBadge(profile.kycStatus),
                  onTap: () => context.push("/kyc"),
                ),
                const SizedBox(height: 10),
                _NavTile(
                  icon: Icons.bar_chart_rounded,
                  label: "Reports",
                  subtitle: "Monthly statements & performance",
                  onTap: () => context.push("/reports"),
                ),
                const SizedBox(height: 10),
                _NavTile(
                  icon: Icons.notifications_outlined,
                  label: "Notifications",
                  subtitle: "Alerts and updates",
                  onTap: () => context.push("/notifications"),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _kycSubtitle(KycLifecycleStatus s) => switch (s) {
    KycLifecycleStatus.approved => "Verified — full access enabled",
    KycLifecycleStatus.underReview => "Under review by our team",
    KycLifecycleStatus.rejected => "Action required — re-submit documents",
    KycLifecycleStatus.pending => "Complete identity verification",
  };

  _KycBadgeData? _kycBadge(KycLifecycleStatus s) => switch (s) {
    KycLifecycleStatus.approved => _KycBadgeData(
      label: "Verified",
      color: AppColors.success,
    ),
    KycLifecycleStatus.underReview => _KycBadgeData(
      label: "In review",
      color: Colors.blue.shade700,
    ),
    KycLifecycleStatus.rejected => _KycBadgeData(
      label: "Rejected",
      color: AppColors.error,
    ),
    KycLifecycleStatus.pending => _KycBadgeData(
      label: "Pending",
      color: AppColors.warning,
    ),
  };
}

// ─── App bar ────────────────────────────────────────────────────────────────

class _DashboardAppBar extends StatelessWidget {
  const _DashboardAppBar({required this.profile});
  final AppUser profile;

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

    return SliverAppBar(
      expandedHeight: 0,
      pinned: true,
      backgroundColor: AppColors.backgroundTop,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0.5,
      elevation: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppColors.heading),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Good day,",
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.bodyMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                profile.name.isNotEmpty ? profile.name : "Investor",
                style: const TextStyle(
                  fontSize: 17,
                  color: AppColors.heading,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}

// ─── Drawer ─────────────────────────────────────────────────────────────────

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer({required this.profile});
  final AppUser profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = profile.name.isNotEmpty
        ? profile.name
              .trim()
              .split(" ")
              .map((w) => w[0].toUpperCase())
              .take(2)
              .join()
        : "?";

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Profile header
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
                    profile.name.isNotEmpty ? profile.name : "Investor",
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

            const SizedBox(height: 8),

            // Nav items
            _DrawerItem(
              icon: Icons.dashboard_outlined,
              label: "Dashboard",
              onTap: () {
                Navigator.pop(context);
              },
            ),
            _DrawerItem(
              icon: Icons.pie_chart,
              label: "My portfolio",
              onTap: () {
                Navigator.pop(context);
                context.push("/portfolio");
              },
            ),
            _DrawerItem(
              icon: Icons.account_balance_wallet_outlined,
              label: "Wallet & ledger",
              onTap: () {
                Navigator.pop(context);
                context.push("/wallet-ledger");
              },
            ),
            _DrawerItem(
              icon: Icons.shield_outlined,
              label: "KYC verification",
              onTap: () {
                Navigator.pop(context);
                context.push("/kyc");
              },
            ),
            _DrawerItem(
              icon: Icons.bar_chart_rounded,
              label: "Reports",
              onTap: () {
                Navigator.pop(context);
                context.push("/reports");
              },
            ),
            _DrawerItem(
              icon: Icons.notifications_outlined,
              label: "Notifications",
              onTap: () {
                Navigator.pop(context);
                context.push("/notifications");
              },
            ),

            const Spacer(),
            const Divider(height: 1),
            _DrawerItem(
              icon: Icons.logout_rounded,
              label: "Logout",
              iconColor: AppColors.error,
              labelColor: AppColors.error,
              onTap: () async {
                Navigator.pop(context);
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go("/login");
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
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: labelColor ?? AppColors.body,
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
    final (label, color) = switch (status) {
      KycLifecycleStatus.approved => ("KYC Verified", AppColors.success),
      KycLifecycleStatus.underReview => ("Under Review", Colors.blue.shade600),
      KycLifecycleStatus.rejected => ("KYC Rejected", AppColors.error),
      KycLifecycleStatus.pending => ("KYC Pending", AppColors.warning),
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
            label,
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

    final (
      Color bg,
      Color fg,
      IconData icon,
      String title,
      String subtitle,
    ) = switch (profile.kycStatus) {
      KycLifecycleStatus.pending => (
        const Color(0xFFFFF8E1),
        AppColors.warning,
        Icons.info_outline_rounded,
        "Complete your KYC",
        "Verify your identity to unlock deposits, withdrawals and full access.",
      ),
      KycLifecycleStatus.underReview => (
        const Color(0xFFE3F2FD),
        Colors.blue.shade700,
        Icons.hourglass_top_rounded,
        "Verification in progress",
        "Your documents are under review. We'll notify you once done.",
      ),
      KycLifecycleStatus.rejected => (
        const Color(0xFFFFEBEE),
        AppColors.error,
        Icons.warning_amber_rounded,
        "Action required",
        "Your KYC was not approved. Please review and re-submit.",
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
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: fg,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
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
                          ? "Re-submit KYC →"
                          : "Start verification →",
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

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.wallet});
  final Map<String, dynamic>? wallet;

  @override
  Widget build(BuildContext context) {
    final current = (wallet?["currentBalance"] as num?)?.toDouble() ?? 0;
    final avail = (wallet?["availableBalance"] as num?)?.toDouble() ?? 0;
    final reserved = (wallet?["reservedAmount"] as num?)?.toDouble() ?? 0;
    final td = (wallet?["totalDeposited"] as num?)?.toDouble() ?? 0;
    final tp = (wallet?["totalProfit"] as num?)?.toDouble() ?? 0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Current balance",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Live",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              wallet == null ? "—" : _money.format(current),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _WalletStat(
                    label: "Available",
                    value: wallet == null ? "—" : _money.format(avail),
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _WalletStat(
                    label: "Reserved",
                    value: wallet == null ? "—" : _money.format(reserved),
                    align: TextAlign.center,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _WalletStat(
                    label: "Profit",
                    value: wallet == null ? "—" : _money.format(tp),
                    align: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.arrow_downward_rounded,
                  size: 14,
                  color: Colors.white70,
                ),
                const SizedBox(width: 4),
                Text(
                  "Total deposited: ${wallet == null ? "—" : _money.format(td)}",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
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
            label: "Deposit",
            enabled: approved,
            onTap: () => context.push("/wallet-ledger/deposit"),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.arrow_upward_rounded,
            label: "Withdraw",
            enabled: approved,
            onTap: () => context.push("/wallet-ledger/withdraw"),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.history_rounded,
            label: "History",
            onTap: () => context.push("/wallet-ledger"),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.description_outlined,
            label: "Reports",
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
    this.enabled = true,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? AppColors.surface : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled
                ? AppColors.border
                : AppColors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: enabled ? AppColors.primary : AppColors.bodyMuted,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: enabled ? AppColors.body : AppColors.bodyMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section label ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.bodyMuted,
        letterSpacing: 0.4,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.heading,
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.bodyMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.bodyMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
