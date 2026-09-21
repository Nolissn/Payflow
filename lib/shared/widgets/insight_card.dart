import 'package:flutter/material.dart';

import '../../core/theme/brand.dart';
import '../../domain/models/insight.dart';
import '../../state/app_scope.dart';
import 'expense_tiles.dart';
import 'surfaces.dart';

IconData _iconFor(InsightKind kind) => switch (kind) {
      InsightKind.categoryCluster => Icons.stacked_bar_chart_rounded,
      InsightKind.mostExpensive => Icons.trending_up_rounded,
      InsightKind.upcomingYearly => Icons.event_repeat_rounded,
      InsightKind.deadlineSoon => Icons.timer_outlined,
      InsightKind.trialEnding => Icons.hourglass_bottom_rounded,
      InsightKind.smallAddUp => Icons.grain_rounded,
      InsightKind.concentration => Icons.pie_chart_outline_rounded,
      InsightKind.pausedSavings => Icons.pause_circle_outline_rounded,
    };

/// A neutral, fact-based observation worth reviewing.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.insight, this.width});

  final Insight insight;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final attention = insight.tone == InsightTone.attention;
    final single = insight.expenseIds.length == 1
        ? context.store.overview.byId(insight.expenseIds.first)
        : null;

    return SizedBox(
      width: width,
      child: SurfaceCard(
        padding: const EdgeInsets.all(16),
        onTap: single == null ? null : () => openExpense(context, single),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: attention ? c.accentSoft : c.primarySoft,
                borderRadius: BorderRadius.circular(Brand.radiusS + 2),
              ),
              child: Icon(
                _iconFor(insight.kind),
                size: 19,
                color: attention ? c.onAccentSoft : c.onPrimarySoft,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(insight.title, style: context.text.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    insight.message,
                    style: context.text.bodyMedium!.copyWith(
                      color: c.textSecondary,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            if (single != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
