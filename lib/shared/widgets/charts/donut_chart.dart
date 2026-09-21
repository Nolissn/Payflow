import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/brand.dart';

class ChartSegment {
  const ChartSegment({required this.value, required this.color, this.label});

  final double value;
  final Color color;
  final String? label;
}

/// Animated donut with tappable segments. The centre shows [center], or the
/// result of [centerBuilder] for the selected segment.
class DonutChart extends StatefulWidget {
  const DonutChart({
    super.key,
    required this.segments,
    this.size = 180,
    this.thickness = 22,
    this.center,
    this.selectedIndex,
    this.onSelected,
    this.semanticsLabel,
  });

  final List<ChartSegment> segments;
  final double size;
  final double thickness;
  final Widget? center;
  final int? selectedIndex;
  final ValueChanged<int?>? onSelected;
  final String? semanticsLabel;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  static const _gapRadians = 0.035;

  int? _hitTest(Offset local) {
    final c = Offset(widget.size / 2, widget.size / 2);
    final v = local - c;
    final dist = v.distance;
    final outer = widget.size / 2;
    if (dist < outer - widget.thickness - 10 || dist > outer + 6) return null;
    var angle = math.atan2(v.dy, v.dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    final total = widget.segments.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return null;
    var acc = 0.0;
    for (var i = 0; i < widget.segments.length; i++) {
      acc += widget.segments[i].value / total * 2 * math.pi;
      if (angle <= acc) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: widget.semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: widget.onSelected == null
            ? null
            : (d) {
                final hit = _hitTest(d.localPosition);
                widget.onSelected!(hit == widget.selectedIndex ? null : hit);
              },
        child: SizedBox.square(
          dimension: widget.size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, progress, child) => CustomPaint(
              painter: _DonutPainter(
                segments: widget.segments,
                thickness: widget.thickness,
                progress: progress,
                track: c.chartTrack,
                selected: widget.selectedIndex,
                gap: widget.segments.length > 1 ? _gapRadians : 0,
              ),
              child: child,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(widget.thickness + 8),
                child: widget.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.segments,
    required this.thickness,
    required this.progress,
    required this.track,
    required this.selected,
    required this.gap,
  });

  final List<ChartSegment> segments;
  final double thickness;
  final double progress;
  final Color track;
  final int? selected;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - thickness / 2 - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = track,
    );
    final total = segments.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return;

    var start = -math.pi / 2;
    final sweepTotal = 2 * math.pi * progress;
    for (var i = 0; i < segments.length; i++) {
      final sweep = segments[i].value / total * sweepTotal;
      final visible = math.max(0.0, sweep - gap);
      final isSelected = selected == i;
      final dimmed = selected != null && !isSelected;
      if (visible > 0) {
        canvas.drawArc(
          isSelected ? rect.inflate(2) : rect,
          start + gap / 2,
          visible,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? thickness + 6 : thickness
            ..color = dimmed
                ? segments[i].color.withValues(alpha: 0.28)
                : segments[i].color,
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.segments != segments ||
      old.track != track;
}
