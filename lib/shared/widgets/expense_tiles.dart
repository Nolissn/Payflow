import 'package:flutter/material.dart';

import '../../core/formatting/date_format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/date_math.dart';
import '../../domain/models/billing_cycle.dart';
import '../../domain/models/expense_status.dart';
import '../../domain/models/recurring_expense.dart';
import '../../domain/services/cost_calculator.dart';
import '../../domain/services/payment_schedule.dart';
import '../../features/expense_detail/expense_detail_screen.dart';
import '../../state/app_scope.dart';
import 'category_visuals.dart';
import 'surfaces.dart';

/// "€13.99 / month" style price label.
String priceLabel(BuildContext context, RecurringExpense e) =>
    '${context.money(e.amount)} / ${e.cycle.perLabel}';

void openExpense(BuildContext context, RecurringExpense e) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => ExpenseDetailScreen(expenseId: e.id),
  ));
}

/// A recurring expense row: avatar, name, category & next date, price.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.expense,
    this.showMonthlyEquivalent = true,
    this.onTap,
  });

  final RecurringExpense expense;
  final bool showMonthlyEquivalent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final overview = store.overview;
    final category = overview.categoryOf(expense.categoryId);
    final c = context.colors;
    final next = overview.nextPaymentOf(expense);
    final inactive = !expense.status.isBilled;
    final showEquivalent = showMonthlyEquivalent &&
        expense.cycle != BillingCycle.monthly &&
        !inactive;

    final subtitle = switch (expense.status) {
      ExpenseStatus.paused => 'Paused',
      ExpenseStatus.cancelled => 'Cancelled',
      _ when next == null => category.name,
      _ => '${category.name} · ${Dates.short(next, reference: overview.today)}',
    };

    return Semantics(
      button: true,
      label: '${expense.name}, ${priceLabel(context, expense)}, $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap ?? () => openExpense(context, expense),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              ExpenseAvatar(expense: expense, category: category, muted: inactive),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            expense.name,
                            style: context.text.titleSmall!.copyWith(
                              fontSize: 15,
                              color: inactive ? c.textSecondary : c.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (expense.status == ExpenseStatus.trial) ...[
                          const SizedBox(width: 6),
                          const Tag('Trial', tone: TagTone.accent),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: context.text.bodySmall,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    context.money(expense.amount),
                    style: context.text.titleSmall!.figures.copyWith(
                      fontSize: 15,
                      color: inactive ? c.textMuted : c.textPrimary,
                      decoration:
                          expense.status == ExpenseStatus.cancelled
                              ? TextDecoration.lineThrough
                              : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    showEquivalent
                        ? '~${context.money(CostCalculator.monthly(expense))}/mo'
                        : '/ ${expense.cycle.perLabel}',
                    style: context.text.bodySmall!.figures,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single upcoming charge with a calendar-style date block.
class PaymentTile extends StatelessWidget {
  const PaymentTile({super.key, required this.payment, this.dense = false});

  final PaymentOccurrence payment;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final overview = context.store.overview;
    final e = payment.expense;
    final category = overview.categoryOf(e.categoryId);
    final isLarge = overview.isLarge(payment.amount);
    final c = context.colors;
    final days = DateMath.daysBetween(overview.today, payment.date);
    final relative = Dates.relative(payment.date, overview.today);
    final meta = [
      if (!dense) category.name,
      if (e.cycle != BillingCycle.monthly) e.cycle.label,
    ].join(' · ');

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${e.name}, ${context.money(payment.amount)}, '
          '${Dates.long(payment.date)}${isLarge ? ', large payment' : ''}',
      child: InkWell(
        onTap: () => openExpense(context, e),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: dense ? 10 : 12),
          child: Row(
            children: [
              _DateBlock(date: payment.date, highlight: days <= 1),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name,
                        style: context.text.titleSmall!.copyWith(fontSize: 15),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                      meta.isEmpty ? relative : '$relative · $meta',
                      style: context.text.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isLarge)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.accentSoft,
                    borderRadius: BorderRadius.circular(Brand.radiusS),
                  ),
                  child: Text(
                    context.money(payment.amount),
                    style: context.text.titleSmall!.figures
                        .copyWith(fontSize: 15, color: c.onAccentSoft),
                  ),
                )
              else
                Text(context.money(payment.amount),
                    style: context.text.titleSmall!.figures.copyWith(fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date, this.highlight = false});

  final DateTime date;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 46,
      height: 50,
      decoration: BoxDecoration(
        color: highlight ? scheme.primary : c.chartTrack,
        borderRadius: BorderRadius.circular(Brand.radiusM),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            Dates.monthShort(date).toUpperCase(),
            style: context.text.labelSmall!.copyWith(
              fontSize: 9.5,
              color: highlight
                  ? scheme.onPrimary.withValues(alpha: 0.8)
                  : c.textMuted,
            ),
          ),
          Text(
            Dates.day(date),
            style: context.text.titleMedium!.figures.copyWith(
              fontSize: 18,
              height: 1.1,
              color: highlight ? scheme.onPrimary : c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
