import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/brand.dart';

/// Geometry of the Payflow mark.
///
/// A single stroke rises as a stem and loops into a bowl — a "P" drawn as a
/// continuous flow. The loop is interrupted on the right by a coin: a payment
/// travelling through the cycle. Recurring, in motion, under control.
class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({
    required this.strokeColor,
    required this.coinColor,
    this.scale = 1,
  });

  final Color strokeColor;
  final Color coinColor;

  /// 1.0 fills roughly 65% of the box height.
  final double scale;

  // Unit geometry (fractions of the box side).
  static const _radius = 0.19;
  static const _stroke = 0.115;
  static const _stem = 0.34;
  static const _coin = 0.063;
  static const _gap = math.pi / 4; // half-angle of the opening around the coin

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final k = side * scale;
    // Visual centre of the composition (stem + bowl + coin).
    final center = Offset(
      size.width / 2 - 0.018 * k,
      size.height / 2 - 0.09 * k,
    );
    final r = _radius * k;
    final rect = Rect.fromCircle(center: center, radius: r);

    final stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // Stem → upper bowl, ending just before the coin.
    final upper = Path()
      ..moveTo(center.dx - r, center.dy + _stem * k)
      ..lineTo(center.dx - r, center.dy)
      ..arcTo(rect, math.pi, math.pi - _gap, false);
    // Lower bowl: from after the coin back into the stem.
    final lower = Path()..addArc(rect, _gap, math.pi - _gap);

    canvas
      ..drawPath(upper, stroke)
      ..drawPath(lower, stroke)
      ..drawCircle(
        Offset(center.dx + r, center.dy),
        _coin * k,
        Paint()
          ..color = coinColor
          ..isAntiAlias = true,
      );
  }

  @override
  bool shouldRepaint(BrandMarkPainter old) =>
      old.strokeColor != strokeColor ||
      old.coinColor != coinColor ||
      old.scale != scale;
}

/// The mark on its own, e.g. in app bars or empty states.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32, this.color, this.coinColor});

  final double size;
  final Color? color;
  final Color? coinColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Payflow',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: BrandMarkPainter(
            strokeColor: color ?? Theme.of(context).colorScheme.primary,
            coinColor: coinColor ?? context.colors.accent,
            scale: 1.35,
          ),
        ),
      ),
    );
  }
}

/// The app-icon tile: the mark on a jade squircle.
class BrandTile extends StatelessWidget {
  const BrandTile({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Payflow',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Brand.jade700,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: CustomPaint(
          painter: const BrandMarkPainter(
            strokeColor: Brand.paper,
            coinColor: Brand.ember400,
          ),
        ),
      ),
    );
  }
}

/// Mark + wordmark lockup.
class PayflowLogo extends StatelessWidget {
  const PayflowLogo({super.key, this.height = 28});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandTile(size: height),
        SizedBox(width: height * 0.32),
        Text(
          'payflow',
          style: TextStyle(
            fontFamily: Brand.fontFamily,
            fontWeight: FontWeight.w800,
            fontSize: height * 0.78,
            letterSpacing: -height * 0.035,
            height: 1,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Soft, sinuous lines — the "flow" motif used behind hero numbers.
class FlowLinesPainter extends CustomPainter {
  const FlowLinesPainter({required this.color, this.phase = 0});

  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..isAntiAlias = true;
    const lines = 7;
    for (var i = 0; i < lines; i++) {
      final t = i / (lines - 1);
      final baseY = size.height * (0.30 + t * 0.85);
      final amp = size.height * (0.10 + 0.05 * math.sin(i + phase));
      final path = Path()..moveTo(-20, baseY);
      const segments = 48;
      for (var s = 1; s <= segments; s++) {
        final x = -20 + (size.width + 40) * s / segments;
        final y = baseY -
            amp * math.sin((x / size.width) * math.pi * 1.6 + i * 0.45 + phase) -
            size.height * 0.28 * (x / size.width) * (1 - t * 0.4);
        path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        paint..color = color.withValues(alpha: color.a * (0.35 + 0.65 * (1 - t))),
      );
    }
  }

  @override
  bool shouldRepaint(FlowLinesPainter old) =>
      old.color != color || old.phase != phase;
}
