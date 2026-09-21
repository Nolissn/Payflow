import 'package:collection/collection.dart';

import '../../core/utils/date_math.dart';
import '../models/category.dart';
import '../models/insight.dart';
import '../models/recurring_expense.dart';
import 'cost_calculator.dart';
import 'expense_analytics.dart';
import 'insights_engine.dart';
import 'payment_schedule.dart';

/// A read-only snapshot of the user's recurring finances at [today].
///
/// Screens read everything they display from here, so business logic lives
/// in one place and every derived value is computed lazily and at most once
/// per data change.
class FinanceOverview {
  FinanceOverview({
    required List<RecurringExpense> expenses,
    required List<ExpenseCategory> categories,
    required DateTime today,
    required this.largePaymentThreshold,
    required this._insightsEngine,
  })  : all = List.unmodifiable(expenses),
        today = DateMath.dateOnly(today),
        _categories = {for (final c in categories) c.id: c};

  final List<RecurringExpense> all;
  final DateTime today;
  final double largePaymentThreshold;
  final Map<String, ExpenseCategory> _categories;
  final InsightsEngine _insightsEngine;

  ExpenseCategory categoryOf(String id) => _categories[id] ?? DefaultCategories.other;

  List<ExpenseCategory> get categories => _categories.values.toList();

  bool isLarge(double amount) => amount >= largePaymentThreshold;

  /// Expenses that are currently charged (active or trial, not ended).
  late final List<RecurringExpense> billed = all
      .where((e) =>
          e.status.isBilled &&
          (e.endDate == null || !DateMath.dateOnly(e.endDate!).isBefore(today)))
      .toList();

  late final CostSummary summary = CostCalculator.summarize(billed);

  late final List<CategoryTotal> byCategory =
      ExpenseAnalytics.byCategory(billed, categoryOf);

  late final List<GroupTotal> byGroup =
      ExpenseAnalytics.byGroup(billed, categoryOf);

  late final List<ProviderTotal> byProvider =
      ExpenseAnalytics.byProvider(billed);

  late final List<FrequencyTotal> byFrequency =
      ExpenseAnalytics.byFrequency(billed);

  late final List<RecurringExpense> largest = ExpenseAnalytics.largest(billed);

  late final List<MonthProjection> projection =
      ExpenseAnalytics.monthlyProjection(billed, today);

  /// Upcoming charges for the next year; shorter windows are views on it.
  late final List<PaymentOccurrence> _upcomingYear = PaymentSchedule.occurrences(
      billed, today, DateMath.addDays(DateMath.addMonths(today, 12), -1));

  List<PaymentOccurrence> upcoming({int days = 30}) {
    final end = DateMath.addDays(today, days);
    return _upcomingYear.where((p) => !p.date.isAfter(end)).toList();
  }

  double upcomingTotal({int days = 30}) =>
      upcoming(days: days).fold(0, (sum, p) => sum + p.amount);

  PaymentOccurrence? get nextPayment => _upcomingYear.firstOrNull;

  List<PaymentOccurrence> largeUpcoming({int days = 90}) =>
      upcoming(days: days).where((p) => isLarge(p.amount)).toList();

  late final List<CancellationDeadline> deadlines = billed
      .map((e) => PaymentSchedule.nextDeadline(e, today))
      .nonNulls
      .sortedBy((d) => d.deadline);

  DateTime? nextPaymentOf(RecurringExpense e) =>
      PaymentSchedule.nextPayment(e, today);

  CancellationDeadline? deadlineOf(RecurringExpense e) =>
      PaymentSchedule.nextDeadline(e, today);

  late final List<Insight> insights = _insightsEngine.generate(
    all: all,
    billed: billed,
    categoryOf: categoryOf,
    today: today,
  );

  RecurringExpense? byId(String id) => all.firstWhereOrNull((e) => e.id == id);
}
