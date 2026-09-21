import 'package:collection/collection.dart';

import '../../core/utils/date_math.dart';
import '../models/billing_cycle.dart';
import '../models/category.dart';
import '../models/expense_status.dart';
import '../models/insight.dart';
import '../models/recurring_expense.dart';
import 'cost_calculator.dart';
import 'expense_analytics.dart';
import 'payment_schedule.dart';

typedef MoneyFormatter = String Function(double amount);
typedef DateFormatter = String Function(DateTime date);

/// Derives neutral, fact-based savings insights from the expense list.
///
/// The engine surfaces areas worth reviewing; it never labels an expense as
/// "bad" or suggests cancelling anything.
class InsightsEngine {
  const InsightsEngine({required this.money, required this.date});

  final MoneyFormatter money;
  final DateFormatter date;

  static const _clusterThreshold = 3;
  static const _yearlyWindowDays = 60;
  static const _deadlineWindowDays = 21;
  static const _smallAmountMonthly = 5.0;

  List<Insight> generate({
    required List<RecurringExpense> all,
    required List<RecurringExpense> billed,
    required ExpenseCategory Function(String id) categoryOf,
    required DateTime today,
  }) {
    if (billed.isEmpty) return const [];
    return [
      ..._deadlines(billed, today),
      ..._trials(billed, today),
      ..._upcomingYearly(billed, today),
      ..._clusters(billed, categoryOf),
      ?_mostExpensive(billed),
      ?_concentration(billed, categoryOf),
      ?_smallAddUp(billed),
      ?_paused(all),
    ];
  }

  Iterable<Insight> _clusters(
    List<RecurringExpense> billed,
    ExpenseCategory Function(String id) categoryOf,
  ) sync* {
    final byCategory = groupBy(billed, (e) => e.categoryId);
    final clusters = byCategory.entries
        .where((e) =>
            e.value.length >= _clusterThreshold &&
            categoryOf(e.key).isSubscription)
        .sortedBy<num>((e) => -e.value.length);
    for (final entry in clusters.take(2)) {
      final category = categoryOf(entry.key);
      final monthly = CostCalculator.summarize(entry.value).monthly;
      yield Insight(
        kind: InsightKind.categoryCluster,
        title: '${entry.value.length} ${category.name.toLowerCase()} services',
        message: 'You spend ${money(monthly)} per month on '
            '${entry.value.length} ${category.name.toLowerCase()} services.',
        expenseIds: entry.value.map((e) => e.id).toList(),
        categoryId: category.id,
      );
    }
  }

  Insight? _mostExpensive(List<RecurringExpense> billed) {
    final top = ExpenseAnalytics.largest(billed).firstOrNull;
    if (top == null || billed.length < 2) return null;
    return Insight(
      kind: InsightKind.mostExpensive,
      title: 'Largest commitment',
      message: 'Your most expensive recurring expense is ${top.name} at '
          '${money(CostCalculator.monthly(top))} per month '
          '(${money(CostCalculator.yearly(top))} per year).',
      expenseIds: [top.id],
    );
  }

  Iterable<Insight> _upcomingYearly(
    List<RecurringExpense> billed,
    DateTime today,
  ) sync* {
    final end = DateMath.addDays(today, _yearlyWindowDays);
    final yearly = billed.where((e) => e.cycle.unit == CycleUnit.year);
    final due = PaymentSchedule.occurrences(yearly, today, end);
    if (due.isEmpty) return;
    final total = due.fold<double>(0, (s, p) => s + p.amount);
    final count = due.length;
    yield Insight(
      kind: InsightKind.upcomingYearly,
      title: 'Yearly payments ahead',
      message: '$count yearly ${count == 1 ? 'payment' : 'payments'} totaling '
          '${money(total)} ${count == 1 ? 'is' : 'are'} coming up within the '
          'next $_yearlyWindowDays days.',
      tone: total >= 200 ? InsightTone.attention : InsightTone.neutral,
      expenseIds: due.map((p) => p.expense.id).toList(),
    );
  }

  Iterable<Insight> _deadlines(
    List<RecurringExpense> billed,
    DateTime today,
  ) sync* {
    final soon = billed
        .map((e) => PaymentSchedule.nextDeadline(e, today))
        .nonNulls
        .where((d) => d.daysLeft <= _deadlineWindowDays)
        .sortedBy<num>((d) => d.daysLeft);
    for (final d in soon.take(2)) {
      final when = switch (d.daysLeft) {
        0 => 'today',
        1 => 'tomorrow',
        _ => 'in ${d.daysLeft} days',
      };
      yield Insight(
        kind: InsightKind.deadlineSoon,
        title: 'Cancellation window closes $when',
        message: '${d.expense.name} renews on ${date(d.renewalDate)}. '
            'The latest cancellation date is ${date(d.deadline)}.',
        tone: InsightTone.attention,
        expenseIds: [d.expense.id],
      );
    }
  }

  Iterable<Insight> _trials(List<RecurringExpense> billed, DateTime today) sync* {
    for (final e in billed.where((e) => e.status == ExpenseStatus.trial)) {
      final next = PaymentSchedule.nextPayment(e, today);
      if (next == null) continue;
      yield Insight(
        kind: InsightKind.trialEnding,
        title: 'Trial converts on ${date(next)}',
        message: 'The ${e.name} trial turns into a paid plan of '
            '${money(e.amount)} per ${e.cycle.perLabel} on ${date(next)}.',
        tone: InsightTone.attention,
        expenseIds: [e.id],
      );
    }
  }

  Insight? _concentration(
    List<RecurringExpense> billed,
    ExpenseCategory Function(String id) categoryOf,
  ) {
    final top = ExpenseAnalytics.byCategory(billed, categoryOf).firstOrNull;
    if (top == null || top.share < 0.25 || billed.length < 4) return null;
    return Insight(
      kind: InsightKind.concentration,
      title: '${top.category.name} leads your spending',
      message: '${top.category.name} makes up ${(top.share * 100).round()}% '
          'of your recurring costs — ${money(top.monthly)} per month.',
      categoryId: top.category.id,
    );
  }

  Insight? _smallAddUp(List<RecurringExpense> billed) {
    final small = billed
        .where((e) => CostCalculator.monthly(e) < _smallAmountMonthly)
        .toList();
    if (small.length < 3) return null;
    final yearly = CostCalculator.summarize(small).yearly;
    return Insight(
      kind: InsightKind.smallAddUp,
      title: 'Small amounts add up',
      message: '${small.length} expenses under ${money(_smallAmountMonthly)} '
          'a month add up to ${money(yearly)} per year.',
      expenseIds: small.map((e) => e.id).toList(),
    );
  }

  Insight? _paused(List<RecurringExpense> all) {
    final paused =
        all.where((e) => e.status == ExpenseStatus.paused).toList();
    if (paused.isEmpty) return null;
    final monthly = CostCalculator.summarize(paused).monthly;
    return Insight(
      kind: InsightKind.pausedSavings,
      title: 'Paused right now',
      message: '${paused.length} paused '
          '${paused.length == 1 ? 'subscription' : 'subscriptions'} '
          'currently keep ${money(monthly)} per month out of your costs.',
      expenseIds: paused.map((e) => e.id).toList(),
    );
  }
}
