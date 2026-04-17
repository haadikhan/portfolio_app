import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../core/i18n/app_translations.dart";
import "../core/theme/app_colors.dart";
import "../providers/auth_providers.dart";

/// Keeps [StatefulNavigationShell] in the tree for every consent state so
/// go_router's shell route stays valid (unlike [ConsentGateScreen], which
/// omits the child while loading).
class InvestorShellWithConsent extends ConsumerWidget {
  const InvestorShellWithConsent({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consentAsync = ref.watch(consentAcceptedProvider);
    final scheme = Theme.of(context).colorScheme;

    return consentAsync.when(
      loading: () => Scaffold(
        body: _stackOverShell(
          navigationShell,
          ColoredBox(
            color: scheme.surface,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        body: _stackOverShell(
          navigationShell,
          ColoredBox(
            color: scheme.surface,
            child: Center(
              child: Text("${context.tr("error_prefix")} $e"),
            ),
          ),
        ),
      ),
      data: (accepted) {
        if (accepted) {
          return InvestorShellScaffold(navigationShell: navigationShell);
        }
        return Scaffold(
          appBar: AppBar(title: Text(context.tr("consent_required_title"))),
          body: _stackOverShell(
            navigationShell,
            ColoredBox(
              color: scheme.surface,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.tr("consent_required_body"),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => context.go("/legal"),
                          child: Text(context.tr("open_legal_consent")),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Widget _stackOverShell(
  StatefulNavigationShell navigationShell,
  Widget overlay,
) {
  return Stack(
    fit: StackFit.expand,
    children: [
      IgnorePointer(
        ignoring: true,
        child: Opacity(
          opacity: 0,
          child: navigationShell,
        ),
      ),
      overlay,
    ],
  );
}

class InvestorShellScaffold extends ConsumerWidget {
  const InvestorShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specs = <_NavItemSpec>[
      _NavItemSpec(
        Icons.home_outlined,
        Icons.home_rounded,
        context.tr("nav_tab_home"),
      ),
      _NavItemSpec(
        Icons.candlestick_chart_outlined,
        Icons.candlestick_chart_rounded,
        context.tr("nav_tab_kmi30"),
      ),
      _NavItemSpec(
        Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet_rounded,
        context.tr("nav_tab_wallet"),
      ),
      _NavItemSpec(
        Icons.person_outline_rounded,
        Icons.person_rounded,
        context.tr("nav_tab_profile"),
      ),
      _NavItemSpec(
        Icons.description_outlined,
        Icons.description_rounded,
        context.tr("nav_tab_reports"),
      ),
    ];

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _InvestorGradientBottomBar(
        navigationShell: navigationShell,
        specs: specs,
      ),
    );
  }
}

class _NavItemSpec {
  const _NavItemSpec(this.outline, this.selected, this.label);
  final IconData outline;
  final IconData selected;
  final String label;
}

class _InvestorGradientBottomBar extends StatelessWidget {
  const _InvestorGradientBottomBar({
    required this.navigationShell,
    required this.specs,
  });

  final StatefulNavigationShell navigationShell;
  final List<_NavItemSpec> specs;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    final BoxDecoration decoration;
    if (isDark) {
      decoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surfaceContainer,
            scheme.surfaceContainerHigh,
          ],
        ),
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      );
    } else {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.32),
            blurRadius: 14,
            offset: const Offset(0, -2),
          ),
        ],
      );
    }

    return Material(
      type: MaterialType.transparency,
      elevation: 0,
      child: DecoratedBox(
        decoration: decoration,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 2),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                for (var i = 0; i < specs.length; i++)
                  Expanded(
                    child: _InvestorBottomNavItem(
                      spec: specs[i],
                      selected: navigationShell.currentIndex == i,
                      isDark: isDark,
                      scheme: scheme,
                      onTap: () {
                        navigationShell.goBranch(
                          i,
                          initialLocation: i == navigationShell.currentIndex,
                        );
                      },
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

class _InvestorBottomNavItem extends StatelessWidget {
  const _InvestorBottomNavItem({
    required this.spec,
    required this.selected,
    required this.isDark,
    required this.scheme,
    required this.onTap,
  });

  final _NavItemSpec spec;
  final bool selected;
  final bool isDark;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color iconColor;
    final Color labelColor;
    if (isDark) {
      iconColor = selected ? scheme.primary : scheme.onSurfaceVariant;
      labelColor = selected ? scheme.primary : scheme.onSurfaceVariant;
    } else {
      iconColor = selected
          ? Colors.white
          : Colors.white.withValues(alpha: 0.68);
      labelColor = selected
          ? Colors.white
          : Colors.white.withValues(alpha: 0.68);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: isDark
            ? scheme.primary.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.2),
        highlightColor: isDark
            ? scheme.primary.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: selected
                    ? BoxDecoration(
                        color: isDark
                            ? scheme.primary.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Icon(
                  selected ? spec.selected : spec.outline,
                  size: 20,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                spec.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w500,
                  color: labelColor,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
