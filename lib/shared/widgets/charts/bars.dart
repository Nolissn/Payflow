import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/brand.dart';
import 'donut_chart.dart';

/// A single horizontal bar made of proportional segments.
class StackedBar extends StatelessWidget {
  const StackedBar({
    super.key,
    required this.segments,
    this.height = 12,
    this.gap = 3,
    this.trackColor,
  });

  final List<ChartSegment> segments;
  final double height;
  final double gap;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        size: Size(double.infinity, height),
        painter: _StackedBarPainter(
          segments: segments,
          progress: t,
          gap: gap,
          track: trackColor ?? context.colors.chartTrack,
        ),
      ),
    );
  }
}

class _StackedBarPainter extends CustomPainter {
  _StackedBarPainter({
    required this.segments,
    required this.progress,
    required this.gap,
    required this.track,
  });

  final List<ChartSegment> segments;
  final double progress;
  final double gap;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    canvas
      ..save()
      ..clipRRect(RRect.fromRectAndRadius(Offset.zero & size, radius))
      ..drawRect(Offset.zero & size, Paint()..color = track);
    final total = segments.fold<double>(0, (s, e) => s + e.value);
    if (total > 0) {
      final visible = segments.where((s) => s.value > 0).toList();
      final usable = size.width - gap * (visible.length - 1);
      var x = 0.0;
      for (final s in visible) {
        final w = usable * s.value / total * progress;
        canvas.drawRect(
            Rect.fromLTWH(x, 0, w, size.height), Paint()..color = s.color);
        x += w + gap * progress;
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StackedBarPainter old) =>
      old.progress != progress ||
      old.segments != segments ||
      old.track != track;
}

/// A thin progress-style bar showing [fraction] of a whole.
class ShareBar extends StatelessWidget {
  const ShareBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 6,
  });

  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction.clamp(0, 1)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Container(
        height: height,
        decoration: BoxDecoration(
          color: context.colors.chartTrack,
          borderRadius: BorderRadius.circular(height),
        ),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(height),
            ),
          ),
        ),
      ),
    );
  }
}

class ColumnDatum {
  const ColumnDatum({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final double value;

  /// Draw in the accent colour (e.g. months containing large payments).
  final bool highlight;
}

/// Vertical columns with an optional dashed reference line (e.g. the
/// monthly average). Tapping a column selects it.
class ColumnChart extends StatelessWidget {
  const ColumnChart({
    super.key,
    required this.data,
    this.reference,
    this.referenceLabel,
    this.selectedIndex,
    this.onSelected,
    this.height = 170,
  });

  final List<ColumnDatum> data;
  final double? reference;
  final String? referenceLabel;
  final int? selectedIndex;
  final ValueChanged<int>? onSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final primary = Theme.of(context).colorScheme.primary;
    final maxValue = math.max(
      data.fold<double>(0, (m, d) => math.max(m, d.value)),
      reference ?? 0,
    );
    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (context, box) {
        const labelHeight = 22.0;
        final chartHeight = box.maxHeight - labelHeight;
        final slot = box.maxWidth / data.length;
        final barWidth = math.min(22.0, slot * 0.58);
        final refY = reference == null || maxValue == 0
            ? null
            : chartHeight * (1 - reference! / maxValue);

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 850),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => Stack(
            clipBehavior: Clip.none,
            children: [
              if (refY != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: refY,
                  child: CustomPaint(
                    size: Size(box.maxWidth, 1),
                    painter: _DashPainter(c.textMuted.withValues(alpha: 0.6)),
                  ),
                ),
              if (refY != null && referenceLabel != null)
                Positioned(
                  right: 0,
                  top: math.max(0, refY - 18),
                  child: Text(referenceLabel!,
                      style: context.text.labelSmall!.copyWith(
                          color: c.textMuted, letterSpacing: 0.2)),
                ),
              Row(
                children: [
                  for (var i = 0; i < data.length; i++)
                    SizedBox(
                      width: slot,
                      child: Semantics(
                        button: onSelected != null,
                        selected: selectedIndex == i,
                        label: data[i].label,
                        child: InkResponse(
                          onTap: onSelected == null ? null : () => onSelected!(i),
                          radius: slot,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: barWidth,
                                height: maxValue == 0
                                    ? 3
                                    : math.max(
                                        3, chartHeight * data[i].value / maxValue * t),
                                decoration: BoxDecoration(
                                  color: _barColor(context, i, primary),
                                  borderRadius: BorderRadius.circular(barWidth / 2.6),
                                ),
                              ),
                              SizedBox(
                                height: labelHeight,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Text(
                                    data[i].label,
                                    style: context.text.labelSmall!.copyWith(
                                      letterSpacing: 0,
                                      color: selectedIndex == i
                                          ? c.textPrimary
                                          : c.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Color _barColor(BuildContext context, int i, Color primary) {
    final c = context.colors;
    final base = data[i].highlight ? c.accent : primary;
    if (selectedIndex == null || selectedIndex == i) return base;
    return base.withValues(alpha: context.isDark ? 0.35 : 0.3);
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + 3.5, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Legend row: colour dot, label, value and percentage.
class LegendRow extends StatelessWidget {
  const LegendRow({
    super.key,
    required this.color,
    required this.label,
    required this.value,
    this.trailing,
    this.selected = false,
    this.onTap,
  });

  final Color color;
  final String label;
  final String value;
  final String? trailing;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Brand.radiusS),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.chartTrack : Colors.transparent,
          borderRadius: BorderRadius.circular(Brand.radiusS),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: context.text.bodyMedium!
                      .copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
            Text(value, style: context.text.labelLarge!.figures),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 40,
                child: Text(trailing!,
                    textAlign: TextAlign.right,
                    style: context.text.bodySmall!.figures),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
