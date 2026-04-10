import "package:flutter/material.dart";

import "premium_splash_screen.dart";

/// Shows [PremiumSplashScreen] on every cold start, then builds [builder] once.
/// Keeps Firebase / FCM / router tree unchanged; only defers construction until splash ends.
class SplashHost extends StatefulWidget {
  const SplashHost({
    super.key,
    required this.appName,
    required this.builder,
  });

  final String appName;
  final Widget Function() builder;

  @override
  State<SplashHost> createState() => _SplashHostState();
}

class _SplashHostState extends State<SplashHost> {
  bool _showApp = false;

  void _onSplashComplete() {
    if (!mounted) return;
    setState(() => _showApp = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_showApp) {
      return widget.builder();
    }
    // Splash runs above [MaterialApp], so provide Directionality + MediaQuery
    // that [Scaffold] / [SafeArea] in [PremiumSplashScreen] expect.
    return Builder(
      builder: (context) {
        return MediaQuery(
          data: MediaQueryData.fromView(View.of(context)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: PremiumSplashScreen(
              appName: widget.appName,
              onComplete: _onSplashComplete,
            ),
          ),
        );
      },
    );
  }
}
