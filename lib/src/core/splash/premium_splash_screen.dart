import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";

import "../theme/app_colors.dart";

/// Full-screen animated splash using brand colors (cold start only; driven by [SplashHost]).
class PremiumSplashScreen extends StatefulWidget {
  const PremiumSplashScreen({
    super.key,
    required this.appName,
    required this.onComplete,
  });

  final String appName;
  final VoidCallback onComplete;

  @override
  State<PremiumSplashScreen> createState() => _PremiumSplashScreenState();
}

class _PremiumSplashScreenState extends State<PremiumSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _main;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _glowPulse;
  late final Animation<double> _drawProgress;

  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _main = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _main,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _main,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _main,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
      ),
    );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _main,
        curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
      ),
    );
    _glowPulse = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(
        parent: _main,
        curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
      ),
    );
    _drawProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _main,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  static const Duration _kSplashWatchdog = Duration(seconds: 6);

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    unawaited(
      Future<void>.delayed(_kSplashWatchdog, () {
        if (!mounted || _completed) return;
        _finish();
      }),
    );
    await _main.forward();
    if (!mounted || _completed) return;
    _finish();
  }

  void _finish() {
    if (_completed) return;
    _completed = true;
    if (_main.isAnimating) {
      _main.stop();
    }
    widget.onComplete();
  }

  @override
  void dispose() {
    _main.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _main,
      builder: (context, _) {
        final pulse = _glowPulse.value;
        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                        AppColors.primary,
                        AppColors.primaryDark,
                        pulse * 0.15,
                      )!,
                      AppColors.primaryDark,
                    ],
                  ),
                ),
              ),
              Positioned(
                right: -80,
                top: -60,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.25 + pulse * 0.15,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.walletHeroOverlayA,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -50,
                bottom: 80,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.18 + pulse * 0.1,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.walletHeroOverlayB,
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: SizedBox(
                          height: 140,
                          width: 220,
                          child: CustomPaint(
                            painter: _GrowthSparkPainter(
                              progress: _drawProgress.value,
                              lineColor: Colors.white.withValues(alpha: 0.95),
                              fillGlow: AppColors.accent.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Opacity(
                      opacity: _titleOpacity.value,
                      child: Text(
                        widget.appName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Opacity(
                      opacity: _taglineOpacity.value,
                      child: Text(
                        "Growth · Transparency · Trust",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const Spacer(flex: 3),
                    Opacity(
                      opacity: _taglineOpacity.value * 0.9,
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Animated upward trend line with subtle area fill (growth motif).
class _GrowthSparkPainter extends CustomPainter {
  _GrowthSparkPainter({
    required this.progress,
    required this.lineColor,
    required this.fillGlow,
  });

  final double progress;
  final Color lineColor;
  final Color fillGlow;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final w = size.width;
    final h = size.height;
    final pad = 12.0;
    final points = <Offset>[
      Offset(pad, h * 0.72),
      Offset(w * 0.22, h * 0.62),
      Offset(w * 0.42, h * 0.58),
      Offset(w * 0.58, h * 0.38),
      Offset(w * 0.78, h * 0.28),
      Offset(w - pad, h * 0.18),
    ];

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final metric = path.computeMetrics().first;
    final extract = metric.extractPath(0, metric.length * progress);

    final fillPath = Path.from(extract)
      ..lineTo(points.last.dx, h)
      ..lineTo(points.first.dx, h)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          fillGlow,
          fillGlow.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(extract, linePaint);

    if (progress > 0.92) {
      final last = points.last;
      final prev = points[points.length - 2];
      final angle = math.atan2(last.dy - prev.dy, last.dx - prev.dx);
      const arrowLen = 14.0;
      final a1 = angle + math.pi + math.pi / 7;
      final a2 = angle + math.pi - math.pi / 7;
      final p1 = Offset(
        last.dx + arrowLen * math.cos(a1),
        last.dy + arrowLen * math.sin(a1),
      );
      final p2 = Offset(
        last.dx + arrowLen * math.cos(a2),
        last.dy + arrowLen * math.sin(a2),
      );
      final arrow = Path()
        ..moveTo(last.dx, last.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();
      canvas.drawPath(
        arrow,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthSparkPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.lineColor != lineColor;
  }
}
