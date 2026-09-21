import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../core/formatting/date_format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/date_math.dart';
import '../../domain/services/finance_overview.dart';
import '../../domain/services/payment_schedule.dart';
import '../../shared/widgets/category_visuals.dart';
import '../../shared/widgets/expense_tiles.dart';
import '../../shared/widgets/surfaces.dart';
import '../../state/app_scope.dart';

enum Horizon {
  days30('30 days', 30),
  days90('90 days', 90),
  year('12 months', 365);

  const Horizon(this.label, this.days);
  final String label;
  final int days;
}

/// Chronological upcoming payments, and cancellation deadlines.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key, required this.initialTab});

  /// 0 = payments, 1 = deadlines. Driven by the shell for deep links.
  final ValueNotifier<int> initialTab;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  Horizon _horizon = Horizon.days30;

  @override
  Widget build(BuildContext context) {
    final overview = context.store.overview;
    return ValueListenableBuilder<int>(
      valueListenable: widget.initialTab,
      builder: (context, tab, _) => CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Upcoming', style: context.text.headlineMedium),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: [
                          const ButtonSegment(
                              value: 0,
                              label: Text('Payments'),
                              icon: Icon(Icons.event_rounded, size: 18)),
                          ButtonSegment(
                              value: 1,
                              label: Text('Deadlines ${overview.deadlines.length}'),
                              icon: const Icon(Icons.timer_outlined, size: 18)),
                        ],
                        selected: {tab},
                        onSelectionChanged: (s) =>
                            widget.initialTab.value = s.first,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (tab == 0)
            ..._payments(context, overview)
          else
            ..._deadlines(context, overview),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  List<Widget> _payments(BuildContext context, FinanceOverview overview) {
    final payments = overview.upcoming(days: _horizon.days);
    final total = payments.fold<double>(0, (s, p) => s + p.amount);
    final large = payments.where((p) => overview.isLarge(p.amount)).toList();
    final byMonth = groupBy(payments, (p) => DateMath.startOfMonth(p.date));
    final c = context.colors;

    return [
      SliverToBoxAdapter(
        child: SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final h in Horizon.values) ...[
                ChoiceChip(
                  label: Text(h.label),
                  selected: _horizon == h,
                  onSelected: (_) => setState(() => _horizon = h),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SurfaceCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Overline('Due in the next ${_horizon.label}'),
                      const SizedBox(height: 6),
                      AmountText(context.money(total),
                          style: context.text.displaySmall!),
                      const SizedBox(height: 2),
                      Text(
                        '${payments.length} payments'
                        '${large.isEmpty ? '' : ' · ${large.length} large (${context.money(large.fold(0, (s, p) => s + p.amount))})'}',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (payments.isEmpty)
        const SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.event_available_rounded,
            title: 'All clear',
            message: 'No payments are due in this period.',
          ),
        )
      else
        for (final entry in byMonth.entries) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              child: Row(
                children: [
                  Text(
                    entry.key.year == overview.today.year
                        ? Dates.month(entry.key)
                        : Dates.monthYear(entry.key),
                    style: context.text.titleMedium,
                  ),
                  const Spacer(),
                  Text(
                    context.money(entry.value.fold(0, (s, p) => s + p.amount)),
                    style: context.text.labelLarge!.figures
                        .copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SurfaceCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final p in entry.value) PaymentTile(payment: p),
                  ],
                ),
              ),
            ),
          ),
        ],
    ];
  }

  List<Widget> _deadlines(BuildContext context, FinanceOverview overview) {
    final deadlines = overview.deadlines;
    if (deadlines.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.timer_off_outlined,
            title: 'No cancellation deadlines',
            message:
                'Add a cancellation period to a subscription and Payflow '
                'calculates the latest day you can cancel.',
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'The latest day to cancel before each renewal, based on the '
            'notice period.',
            style: context.text.bodySmall,
          ),
        ),
      ),
      SliverList.separated(
        itemCount: deadlines.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _DeadlineTile(deadline: deadlines[i], overview: overview),
        ),
      ),
    ];
  }
}

class _DeadlineTile extends StatelessWidget {
  const _DeadlineTile({required this.deadline, required this.overview});

  final CancellationDeadline deadline;
  final FinanceOverview overview;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = deadline.expense;
    final urgent = deadline.daysLeft <= context.settings.deadlineReminderDays;
    final soon = deadline.daysLeft <= 30;
    final color = urgent ? c.accent : (soon ? c.warning : c.textMuted);
    final category = overview.categoryOf(e.categoryId);
    final daysText = switch (deadline.daysLeft) {
      0 => 'Today',
      1 => '1 day',
      _ => '${deadline.daysLeft} days',
    };

    return SurfaceCard(
      padding: EdgeInsets.zero,
      onTap: () => openExpense(context, e),
      semanticLabel: '${e.name}: cancel by ${Dates.long(deadline.deadline)}, '
          '$daysText left. Renews ${Dates.long(deadline.renewalDate)}.',
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ExpenseAvatar(expense: e, category: category, size: 40),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.name, style: context.text.titleSmall),
                          const SizedBox(height: 3),
                          Text(
                            'Cancel by ${Dates.long(deadline.deadline)}',
                            style: context.text.labelLarge!.copyWith(
                                color: urgent ? c.accent : c.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Renews ${Dates.short(deadline.renewalDate, reference: overview.today)}'
                            ' · ${e.noticePeriod!.label} notice'
                            ' · ${context.money(e.amount)}',
                            style: context.text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(daysText,
                            style: context.text.titleMedium!.figures
                                .copyWith(color: color)),
                        Text('left', style: context.text.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
