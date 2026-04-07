import "dart:math";

import "package:flutter/material.dart";

import "../../data/models/kmi30_bar.dart";

class CandleChartView extends StatelessWidget {
  const CandleChartView({super.key, required this.bars});

  final List<Kmi30Bar> bars;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: CandleChartPainter(
              bars: bars,
              bullish: const Color(0xFF1D9E75),
              bearish: const Color(0xFFE24B4A),
              axisColor: scheme.onSurfaceVariant,
              gridColor: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
        );
      },
    );
  }
}

class CandleChartPainter extends CustomPainter {
  CandleChartPainter({
    required this.bars,
    required this.bullish,
    required this.bearish,
    required this.axisColor,
    required this.gridColor,
  });

  final List<Kmi30Bar> bars;
  final Color bullish;
  final Color bearish;
  final Color axisColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final padL = 42.0;
    final padR = 8.0;
    final padT = 8.0;
    final padB = 22.0;
    final chartW = max(1.0, size.width - padL - padR);
    final chartH = max(1.0, size.height - padT - padB);

    final maxPrice = bars.map((e) => e.high).reduce(max);
    final minPrice = bars.map((e) => e.low).reduce(min);
    final range = max(0.0001, maxPrice - minPrice);

    double yFor(double p) => padT + ((maxPrice - p) / range) * chartH;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = padT + (chartH * i / 3);
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), grid);
    }

    final candleW = chartW / bars.length;
    final bodyW = candleW * 0.55;
    final wick = Paint()..strokeWidth = 1.2;

    for (var i = 0; i < bars.length; i++) {
      final b = bars[i];
      final xC = padL + (i + 0.5) * candleW;
      final yOpen = yFor(b.open);
      final yClose = yFor(b.close);
      final yHigh = yFor(b.high);
      final yLow = yFor(b.low);

      final up = b.close >= b.open;
      final c = up ? bullish : bearish;
      wick.color = c;
      canvas.drawLine(Offset(xC, yHigh), Offset(xC, yLow), wick);

      final top = min(yOpen, yClose);
      final h = max(1.5, (yOpen - yClose).abs());
      final rect = Rect.fromCenter(
        center: Offset(xC, top + h / 2),
        width: bodyW,
        height: h,
      );
      final body = Paint()
        ..color = c
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, body);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < 4; i++) {
      final v = maxPrice - (range * i / 3);
      final y = padT + (chartH * i / 3) - 8;
      textPainter.text = TextSpan(
        text: v.toStringAsFixed(2),
        style: TextStyle(color: axisColor, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(2, y));
    }
  }

  @override
  bool shouldRepaint(covariant CandleChartPainter oldDelegate) {
    return oldDelegate.bars != bars;
  }
}
