import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/brand.dart';
import '../../../domain/services/cost_calculator.dart';
import '../../../shared/widgets/brand_mark.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../../state/app_scope.dart';

/// The headline card: monthly, yearly and daily cost at a glance.
class MonthlyHero extends StatelessWidget {
  const MonthlyHero({
    super.key,
    required this.summary,
    required this.onOpenLifeCost,
  });

  final CostSummary summary;
  final VoidCallback onOpenLifeCost;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final money = context.money;
    final numberStyle = context.text.displayLarge!.copyWith(
      color: c.heroForeground,
    );

    return Semantics(
      container: true,
      label: 'Monthly cost ${money(summary.monthly)}, '
          'yearly cost ${money(summary.yearly)}, '
          'average daily cost ${money(summary.daily)}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Brand.radiusXL),
        child: Material(
          color: c.heroBackground,
          child: InkWell(
            onTap: onOpenLifeCost,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: FlowLinesPainter(color: c.heroLine),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: Overline('Monthly cost',
                                    color: c.heroMuted)),
                            _HeroChip(label: '${summary.count} active'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: summary.monthly),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: AmountText(money(value), style: numberStyle),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _HeroMetric(
                                label: 'Yearly cost',
                                value: money(summary.yearly),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 34,
                              color: c.heroForeground.withValues(alpha: 0.14),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: _HeroMetric(
                                label: 'Average per day',
                                value: money(summary.daily),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(color: c.heroForeground.withValues(alpha: 0.12)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'What does my life cost?',
                                style: context.text.labelLarge!
                                    .copyWith(color: c.heroForeground),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.arrow_forward_rounded,
                                size: 18, color: c.heroForeground),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: context.text.bodySmall!.copyWith(color: c.heroMuted)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: context.text.titleLarge!.figures
                .copyWith(color: c.heroForeground, fontSize: 19),
          ),
        ),
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.heroForeground.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: c.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: context.text.labelMedium!
                  .copyWith(color: c.heroForeground)),
        ],
      ),
    );
  }
}
