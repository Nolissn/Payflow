import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/brand.dart';
import '../../domain/models/category.dart';
import '../../domain/services/cost_calculator.dart';
import '../../shared/widgets/brand_mark.dart';
import '../../shared/widgets/charts/bars.dart';
import '../../shared/widgets/charts/donut_chart.dart';
import '../../shared/widgets/expense_tiles.dart';
import '../../shared/widgets/surfaces.dart';
import '../../state/app_scope.dart';

/// "What does my life cost?" — every recurring commitment, in one number.
///
/// Deliberately immersive: the whole screen uses the deep hero palette in
/// both light and dark mode.
class LifeCostScreen extends StatelessWidget {
  const LifeCostScreen({super.key});

  static const _groupColors = {
    CostGroup.subscriptions: Brand.jade300,
    CostGroup.insurance: Color(0xFF7FB2E5),
    CostGroup.software: Color(0xFFB3A6F5),
    CostGroup.fixedCosts: Brand.ember400,
    CostGroup.other: Color(0xFFD6D0BE),
  };

  @override
  Widget build(BuildContext context) {
    final overview = context.store.overview;
    final summary = overview.summary;
    final c = context.colors;
    final money = context.money;
    final fg = c.heroForeground;
    final muted = c.heroMuted;
    final groups = overview.byGroup;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: c.heroBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: fg,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandMark(size: 24, color: fg, coinColor: c.accent),
              const SizedBox(width: 8),
              Text('Life cost',
                  style: context.text.titleMedium!.copyWith(color: fg)),
            ],
          ),
        ),
        body: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 340,
              child: CustomPaint(painter: FlowLinesPainter(color: c.heroLine)),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 48),
              children: [
                Text('What does my life cost?',
                    style: context.text.headlineSmall!.copyWith(color: fg)),
                const SizedBox(height: 28),
                Overline('Recurring costs', color: muted),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: summary.monthly),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        AmountText(money(v),
                            style: context.text.displayLarge!
                                .copyWith(color: fg, fontSize: 52)),
                        const SizedBox(width: 8),
                        Text('/ month',
                            style: context.text.titleMedium!
                                .copyWith(color: muted)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                        child: _BigMetric(
                            value: money(summary.yearly), label: '/ year')),
                    Expanded(
                        child: _BigMetric(
                            value: money(summary.daily), label: '/ day')),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(Brand.radiusL),
                    border: Border.all(color: fg.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, color: c.accent, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'That is ${money(summary.yearly / (365 * 24))} every hour '
                          '— around the clock, whether you use it or not.',
                          style: context.text.bodyMedium!.copyWith(color: fg),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                _Heading('Breakdown', color: fg),
                const SizedBox(height: 14),
                StackedBar(
                  height: 18,
                  gap: 3,
                  trackColor: fg.withValues(alpha: 0.08),
                  segments: [
                    for (final g in groups)
                      ChartSegment(value: g.yearly, color: _groupColors[g.group]!),
                  ],
                ),
                const SizedBox(height: 14),
                for (final g in groups)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _groupColors[g.group],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.group.label,
                                  style: context.text.titleSmall!
                                      .copyWith(color: fg)),
                              Text(
                                '${g.count} items · ${g.categories.map((c) => c.name).join(', ')}',
                                style: context.text.bodySmall!
                                    .copyWith(color: muted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(money(g.monthly),
                                style: context.text.titleSmall!.figures
                                    .copyWith(color: fg)),
                            Text('${(g.share * 100).round()}%',
                                style: context.text.bodySmall!.figures
                                    .copyWith(color: muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 32),
                _Heading('Over time', color: fg),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.1,
                  children: [
                    for (final (label, years) in const [
                      ('1 week', 7 / 365),
                      ('1 year', 1.0),
                      ('5 years', 5.0),
                      ('10 years', 10.0),
                    ])
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: fg.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(Brand.radiusM),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(label,
                                style: context.text.bodySmall!
                                    .copyWith(color: muted)),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                money.whole(summary.yearly * years),
                                style: context.text.titleLarge!.figures
                                    .copyWith(color: fg),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                _Heading('Biggest drivers', color: fg),
                const SizedBox(height: 8),
                for (final e in overview.largest.take(5))
                  InkWell(
                    onTap: () => openExpense(context, e),
                    borderRadius: BorderRadius.circular(Brand.radiusS),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(e.name,
                                style: context.text.bodyLarge!
                                    .copyWith(color: fg, fontWeight: FontWeight.w600)),
                          ),
                          Text(
                            '${money(CostCalculator.yearly(e))} / yr',
                            style: context.text.labelLarge!.figures
                                .copyWith(color: fg),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 28),
                Text(
                  'Includes every active recurring expense, with weekly, '
                  'quarterly, yearly and custom intervals converted to the '
                  'same period. Paused and cancelled items are excluded.',
                  style: context.text.bodySmall!.copyWith(color: muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BigMetric extends StatelessWidget {
  const _BigMetric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(value,
              style: context.text.headlineMedium!.figures
                  .copyWith(color: c.heroForeground)),
          const SizedBox(width: 6),
          Text(label,
              style: context.text.bodyMedium!.copyWith(color: c.heroMuted)),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(text,
            style: context.text.titleLarge!.copyWith(color: color)),
      );
}
