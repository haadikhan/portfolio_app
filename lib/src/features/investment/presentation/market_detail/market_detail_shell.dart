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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundImageProvider != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.30,
                child: Image(
                  image: backgroundImageProvider!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [accentColor.withValues(alpha: 0.55), scheme.surface],
                ),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 0,
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                foregroundColor: Colors.white,
                iconTheme: const IconThemeData(color: Colors.white),
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
