import "dart:async";
import "dart:math" as math;
import "dart:ui" as ui;

import "package:flutter/material.dart";

import "../theme/app_colors.dart";

/// Full-screen splash: green canvas only — premium animated growth line (wave + upward)
/// with no brand image (cold start; driven by [SplashHost]).
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
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                        const Color(0xFF118038),
                        AppColors.primary,
                        0.35 + pulse * 0.2,
                      )!,
                      Color.lerp(
                        AppColors.primaryDark,
                        const Color(0xFF073818),
                        pulse * 0.15,
                      )!,
                    ],
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

/// Sinusoidal “market line” trending up-right: stroke trims along path; wave phase
/// moves with [motionT] so the line feels alive (up/down motion while growing).
class _PremiumGrowthWavePainter extends CustomPainter {
  _PremiumGrowthWavePainter({
    required this.progress,
    required this.motionT,
    required this.lineCore,
    required this.lineGlow,
  });

  final double progress;
  /// 0–1 full splash timeline — shifts the wave phase for traveling up/down motion.
  final double motionT;
  final Color lineCore;
  final Color lineGlow;

  static const int _segments = 56;

  List<Offset> _points(Size size) {
    final w = size.width;
    final h = size.height;
    final phase = motionT * math.pi * 2.2;
    final pts = <Offset>[];
    for (var i = 0; i <= _segments; i++) {
      final u = i / _segments;
      final x = w * (0.04 + u * 0.92);
      final trend = h * (0.93 - u * 0.86);
      // Up/down wave: amplitude grows slightly with progress so the motion “opens up”.
      final amp = h * 0.052 * (0.55 + 0.45 * progress);
      final wave = amp *
          math.sin(u * math.pi * 5.5 + phase) *
          (0.85 + 0.15 * math.sin(phase * 0.5 + u * 3));
      pts.add(Offset(x, trend + wave));
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
