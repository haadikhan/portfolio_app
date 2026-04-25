import "dart:async";
import "dart:math" as math;
import "dart:ui" as ui;

import "package:flutter/material.dart";

import "../theme/app_colors.dart";

/// Hero photo under a green veil; bundled at [kSplashBackgroundAsset].
const String kSplashBackgroundAsset = "assets/splash/splash_hero_background.png";

/// Full-screen splash: green canvas — bar backdrop + trend line shaped like the app
/// icon (rise, V-dip, higher peak, small dip, sharp finish), driven by [SplashHost].
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
  late final Animation<double> _strokeProgress;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _glowPulse;
  late final Animation<double> _accentBreath;

  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _main = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    _strokeProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _main,
        curve: const Interval(0.0, 0.78, curve: Curves.easeInOutCubicEmphasized),
      ),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _main,
        curve: const Interval(0.48, 0.78, curve: Curves.easeOutCubic),
      ),
    );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _main,
        curve: const Interval(0.58, 0.86, curve: Curves.easeOutCubic),
      ),
    );
    _glowPulse = Tween<double>(begin: 0.32, end: 0.95).animate(
      CurvedAnimation(
        parent: _main,
        curve: const Interval(0.08, 1.0, curve: Curves.easeInOut),
      ),
    );
    _accentBreath = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _main,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  static const Duration _kSplashWatchdog = Duration(seconds: 8);

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
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

  static const Color _orbGreen = Color(0x3818A050);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _main,
      builder: (context, _) {
        final pulse = _glowPulse.value;
        return Scaffold(
          backgroundColor: AppColors.primaryDark,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Image.asset(
                  kSplashBackgroundAsset,
                  fit: BoxFit.cover,
                  // Slight positive X: crop favors the right side of the asset so the
                  // scene reads shifted left on screen (portrait phones).
                  alignment: const Alignment(0.2, 0),
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(
                          const Color(0xFF118038),
                          AppColors.primary,
                          0.35 + pulse * 0.2,
                        )!.withValues(alpha: 0.46),
                        Color.lerp(
                          AppColors.primaryDark,
                          const Color(0xFF073818),
                          pulse * 0.15,
                        )!.withValues(alpha: 0.54),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -80,
                top: -40,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.28 + pulse * 0.14,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _orbGreen,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -36,
                bottom: 64,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.22 + pulse * 0.12,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _orbGreen.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    SizedBox(
                      height: 240,
                      width: MediaQuery.sizeOf(context).width,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: CustomPaint(
                          painter: _PremiumGrowthWavePainter(
                            progress: _strokeProgress.value,
                            motionT: _accentBreath.value,
                            lineCore: Colors.white.withValues(alpha: 0.96),
                            lineGlow: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Opacity(
                      opacity: _titleOpacity.value,
                      child: Text(
                        widget.appName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.35,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: _taglineOpacity.value,
                      child: Text(
                        "Growth · Transparency · Trust",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.35,
                        ),
                      ),
                    ),
                    const Spacer(flex: 3),
                    Opacity(
                      opacity: _taglineOpacity.value * 0.85,
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
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

/// Matches the in-app “growth chart” icon: bars in the back, then a line that
/// rises → dips in a V (stays above the start) → climbs higher → shallow pullback →
/// sharp final ascent. [motionT] nudges micro motion along the stroke.
class _PremiumGrowthWavePainter extends CustomPainter {
  _PremiumGrowthWavePainter({
    required this.progress,
    required this.motionT,
    required this.lineCore,
    required this.lineGlow,
  });

  final double progress;
  final double motionT;
  final Color lineCore;
  final Color lineGlow;

  static const int _segments = 72;

  /// Horizontal key times (0 → 1) along the stroke.
  static const List<double> _ku = [
    0.0,
    0.13,
    0.30,
    0.46,
    0.60,
    0.74,
    0.86,
    1.0,
  ];

  /// Absolute Y as fraction of canvas height (0 = top, 1 = bottom): icon-shaped path.
  static const List<double> _ky = [
    0.89, // start low left
    0.55, // first moderate peak
    0.72, // first valley — still clearly above start
    0.39, // second peak — higher than first
    0.48, // shallow retracement
    0.34, // climb again
    0.26, // approach final thrust
    0.11, // highest point, sharp finish up-right
  ];

  static double _interpY(double u) {
    u = u.clamp(0.0, 1.0);
    for (var k = 0; k < _ku.length - 1; k++) {
      if (u <= _ku[k + 1]) {
        final span = _ku[k + 1] - _ku[k];
        final t = span > 1e-9
            ? ((u - _ku[k]) / span).clamp(0.0, 1.0)
            : 0.0;
        final s = t * t * (3.0 - 2.0 * t);
        return _ky[k] + (_ky[k + 1] - _ky[k]) * s;
      }
    }
    return _ky.last;
  }

  /// Soft bar chart behind the line (icon-style pillars), growing with [progress].
  void _paintBarBackdrop(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final grow = (progress * 1.35).clamp(0.0, 1.0);
    if (grow <= 0.01) return;

    final left = w * 0.055;
    final usable = w * 0.89;
    const n = 8;
    final pitch = usable / (n + 0.65);
    final barW = pitch * 0.42;
    final bottom = h * 0.905;
    final topLimit = h * 0.14;
    final maxH = bottom - topLimit;

    // Heights (relative) — uneven, like a market strip behind the trend.
    const relH = [0.38, 0.55, 0.30, 0.68, 0.45, 0.78, 0.36, 0.52];
    final baseAlpha = 0.07 + 0.06 * progress;

    for (var i = 0; i < n; i++) {
      final cx = left + pitch * (i + 0.55);
      final bh = maxH * relH[i] * grow;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - barW * 0.5, bottom - bh, cx + barW * 0.5, bottom),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: baseAlpha)
          ..style = PaintingStyle.fill,
      );
    }
  }

  List<Offset> _points(Size size) {
    final w = size.width;
    final h = size.height;
    final phase = motionT * math.pi * 2.0;
    final pts = <Offset>[];
    for (var i = 0; i <= _segments; i++) {
      final u = i / _segments;
      final x = w * (0.04 + u * 0.92);
      var y = h * _interpY(u);
      // Very light shimmer so the stroke breathes without fighting the icon shape.
      final microAmp = h * 0.0075 * (0.5 + 0.5 * progress);
      y += microAmp * math.sin(u * math.pi * 5 + phase) * (1.0 - u * 0.35);
      pts.add(Offset(x, y));
    }
    return pts;
  }

  Path _fullPath(List<Offset> points) {
    final p = Path()..moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      p.lineTo(points[i].dx, points[i].dy);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    _paintBarBackdrop(canvas, size);

    final points = _points(size);
    final full = _fullPath(points);
    final metric = full.computeMetrics().first;
    final len = metric.length * progress;
    final strokePath = metric.extractPath(0, len);

    // Soft outer glow
    final glowPaint = Paint()
      ..color = lineGlow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);

    canvas.drawPath(strokePath, glowPaint);

    // Crisp highlight core
    final corePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, size.height * 0.2),
        Offset(size.width, size.height * 0.95),
        [
          Colors.white.withValues(alpha: 0.75),
          lineCore,
          Colors.white.withValues(alpha: 0.88),
        ],
        [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.75
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(strokePath, corePaint);

    // Leading cap: subtle pulse at the draw head
    if (len > 8 && progress < 0.995) {
      final tangent = metric.getTangentForOffset(len);
      if (tangent != null) {
        final tip = tangent.position;
        final r = 3.2 + 1.2 * math.sin(motionT * math.pi * 2);
        canvas.drawCircle(
          tip,
          r,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.45)
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3),
        );
        canvas.drawCircle(
          tip,
          2.2,
          Paint()..color = Colors.white.withValues(alpha: 0.95),
        );
      }
    }

    // Arrowhead when path nearly complete
    if (progress > 0.9 && points.length >= 2) {
      final end = points.last;
      final prev = points[points.length - 2];
      final angle = math.atan2(end.dy - prev.dy, end.dx - prev.dx);
      const arrowLen = 13.0;
      final a1 = angle + math.pi + math.pi / 6.5;
      final a2 = angle + math.pi - math.pi / 6.5;
      final p1 = Offset(
        end.dx + arrowLen * math.cos(a1),
        end.dy + arrowLen * math.sin(a1),
      );
      final p2 = Offset(
        end.dx + arrowLen * math.cos(a2),
        end.dy + arrowLen * math.sin(a2),
      );
      final head = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();
      canvas.drawPath(
        head,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.95)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumGrowthWavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.motionT != motionT ||
        oldDelegate.lineCore != lineCore ||
        oldDelegate.lineGlow != lineGlow;
  }
}
