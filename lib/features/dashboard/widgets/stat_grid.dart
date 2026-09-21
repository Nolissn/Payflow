import 'package:flutter/material.dart';

import '../../../core/formatting/date_format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/brand.dart';
import '../../../domain/models/expense_status.dart';
import '../../../shared/widgets/expense_tiles.dart';
import '../../../state/app_scope.dart';
import '../../shell/app_shell.dart';

/// Four key facts under the hero: active count, next payment,
/// next 30 days and the nearest cancellation deadline.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final settings = context.settings;
    final overview = store.overview;
    final money = context.money;
    final shell = ShellScope.of(context);

    final trials =
        overview.billed.where((e) => e.status == ExpenseStatus.trial).length;
    final paused =
        overview.all.where((e) => e.status == ExpenseStatus.paused).length;
    final next = overview.nextPayment;
    final next30 = overview.upcoming(days: 30);
    final deadline = overview.deadlines.firstOrNull;
    final deadlineUrgent =
        deadline != null && deadline.daysLeft <= settings.deadlineReminderDays;

    final tiles = [
      _StatTile(
        icon: Icons.layers_rounded,
        label: 'Active',
        value: '${overview.billed.length}',
        caption: [
          if (trials > 0) '$trials in trial',
          if (paused > 0) '$paused paused',
          if (trials == 0 && paused == 0) 'recurring expenses',
        ].join(' · '),
        onTap: () => shell.select(AppTab.subscriptions),
      ),
      _StatTile(
        icon: Icons.bolt_rounded,
        label: 'Next payment',
        value: next == null ? '—' : money(next.amount),
        caption: next == null
            ? 'Nothing scheduled'
            : '${next.expense.name} · '
                '${Dates.relative(next.date, overview.today).toLowerCase()}',
        onTap: next == null ? null : () => openExpense(context, next.expense),
      ),
      _StatTile(
        icon: Icons.date_range_rounded,
        label: 'Next 30 days',
        value: money(next30.fold<double>(0, (s, p) => s + p.amount)),
        caption:
            '${next30.length} ${next30.length == 1 ? 'payment' : 'payments'}',
        onTap: () => shell.select(AppTab.upcoming, subTab: 0),
      ),
      _StatTile(
        icon: Icons.timer_outlined,
        label: 'Cancel by',
        value: deadline == null
            ? '—'
            : Dates.short(deadline.deadline, reference: overview.today),
        caption: deadline == null
            ? 'No notice periods'
            : '${deadline.expense.name} · ${_daysLeft(deadline.daysLeft)}',
        attention: deadlineUrgent,
        onTap: () => shell.select(AppTab.upcoming, subTab: 1),
      ),
    ];

    return LayoutBuilder(builder: (context, box) {
      // Two columns everywhere except very narrow screens.
      final columns = box.maxWidth < 300 ? 1 : 2;
      const spacing = 12.0;
      final width = (box.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final tile in tiles) SizedBox(width: width, child: tile),
        ],
      );
    });
  }

  static String _daysLeft(int days) => switch (days) {
        0 => 'today',
        1 => '1 day left',
        _ => '$days days left',
      };
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    this.onTap,
    this.attention = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final VoidCallback? onTap;
  final bool attention;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final iconColor = attention ? c.onAccentSoft : c.onPrimarySoft;
    final iconBg = attention ? c.accentSoft : c.primarySoft;
    return Semantics(
      button: onTap != null,
      label: '$label: $value, $caption',
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 15, color: iconColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(label,
                          style: context.text.labelMedium!
                              .copyWith(color: c.textSecondary),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: context.text.headlineSmall!.figures.copyWith(
                      fontWeight: FontWeight.w800,
                      color: attention ? c.accent : c.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: context.text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
