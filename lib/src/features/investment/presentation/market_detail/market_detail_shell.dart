import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

/// Shared scaffold for per-market detail pages (background image + scrollable body).
class MarketDetailShell extends StatelessWidget {
  const MarketDetailShell({
    super.key,
    required this.title,
    required this.accentColor,
    this.backgroundImageProvider,
    required this.child,
    this.fallbackRoute = "/investor",
  });

  final String title;
  final Color accentColor;
  final ImageProvider? backgroundImageProvider;
  final Widget child;

  /// Used when [GoRouter.canPop] is false (e.g. deep-linked with `go()`).
  final String fallbackRoute;

  @override
  Widget build(BuildContext context) {
    final canPop = GoRouter.of(context).canPop();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        scrolledUnderElevation: 0,
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
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundImageProvider != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.08,
                child: Image(
                  image: backgroundImageProvider!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          SingleChildScrollView(child: child),
        ],
      ),
    );
  }
}
