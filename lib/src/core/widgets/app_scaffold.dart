import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../branding/brand_assets.dart";
import "app_bar_actions.dart";

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.fallbackRoute = "/investor",
    this.showNotificationAction = true,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  /// Route to go to when the back button is tapped and there is no
  /// previous entry in the navigation stack (e.g. navigated with go()).
  final String fallbackRoute;

  /// Investor notifications shortcut in the app bar; set false for admin-only screens.
  final bool showNotificationAction;

  @override
  Widget build(BuildContext context) {
    final canPop = GoRouter.of(context).canPop();
    final scheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.5,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (canPop) {
              context.pop();
            } else {
              context.go(fallbackRoute);
            }
          },
        ),
        title: Row(
          children: [
            Image.asset(
              BrandAssets.logoPng,
              height: 26,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: titleStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          ...actions,
          AppBarPreferenceActions(showNotificationAction: showNotificationAction),
          const SizedBox(width: 4),
        ],
      ),
      body: body,
    );
  }
}
