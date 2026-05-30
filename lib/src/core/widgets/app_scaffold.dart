import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../branding/brand_logo.dart";
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

    final compactBar = MediaQuery.sizeOf(context).width < 400;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.5,
        elevation: 0,
        leadingWidth: 40,
        titleSpacing: 8,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          onPressed: () {
            if (canPop) {
              context.pop();
            } else {
              context.go(fallbackRoute);
            }
          },
        ),
        title: compactBar
            ? Text(
                title,
                style: titleStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : Row(
                children: [
                  const SizedBox(
                    width: 32,
                    height: 24,
                    child: BrandLogo(height: 24),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      title,
                      style: titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
        actions: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...actions,
                AppBarPreferenceActions(
                  showNotificationAction: showNotificationAction,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: body,
    );
  }
}
