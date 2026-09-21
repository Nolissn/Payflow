import 'package:collection/collection.dart';

import '../../core/utils/date_math.dart';
import '../models/billing_cycle.dart';
import '../models/category.dart';
import '../models/recurring_expense.dart';
import 'cost_calculator.dart';
import 'payment_schedule.dart';

/// Base for any "share of the total" slice.
abstract class CostShare {
  const CostShare({required this.yearly, required this.count, required this.share});

  final double yearly;
  final int count;

  /// Fraction (0–1) of the overall yearly total.
  final double share;

  double get monthly => yearly / 12;
}

class CategoryTotal extends CostShare {
  const CategoryTotal({
    required this.category,
    required super.yearly,
    required super.count,
    required super.share,
  });
  final ExpenseCategory category;
}

class GroupTotal extends CostShare {
  const GroupTotal({
    required this.group,
    required super.yearly,
    required super.count,
    required super.share,
    required this.categories,
  });
  final CostGroup group;
  final List<ExpenseCategory> categories;
}

class ProviderTotal extends CostShare {
  const ProviderTotal({
    required this.name,
    required this.categoryId,
    required super.yearly,
    required super.count,
    required super.share,
  });
  final String name;
  final String categoryId;
}

class FrequencyTotal extends CostShare {
  const FrequencyTotal({
    required this.frequency,
    required super.yearly,
    required super.count,
    required super.share,
  });
  final BillingFrequency frequency;
}

/// Actual charges falling into one calendar month.
class MonthProjection {
  const MonthProjection(this.month, this.payments);

  final DateTime month;
  final List<PaymentOccurrence> payments;

  double get total => payments.fold(0, (sum, p) => sum + p.amount);
}

/// Pure aggregation functions over a list of (billed) expenses.
abstract final class ExpenseAnalytics {
  static List<CategoryTotal> byCategory(
    List<RecurringExpense> expenses,
    ExpenseCategory Function(String id) categoryOf,
  ) {
    final total = _total(expenses);
    final groups = groupBy(expenses, (e) => e.categoryId);
    return [
      for (final entry in groups.entries)
        CategoryTotal(
          category: categoryOf(entry.key),
          yearly: _total(entry.value),
          count: entry.value.length,
          share: _share(_total(entry.value), total),
        ),
    ]..sort((a, b) => b.yearly.compareTo(a.yearly));
  }

  static List<GroupTotal> byGroup(
    List<RecurringExpense> expenses,
    ExpenseCategory Function(String id) categoryOf,
  ) {
    final total = _total(expenses);
    final groups = groupBy(expenses, (e) => categoryOf(e.categoryId).group);
    return [
      for (final group in CostGroup.values)
        if (groups[group] case final items?)
          GroupTotal(
            group: group,
            yearly: _total(items),
            count: items.length,
            share: _share(_total(items), total),
            categories: items.map((e) => categoryOf(e.categoryId)).toSet().toList(),
          ),
    ]..sort((a, b) => b.yearly.compareTo(a.yearly));
  }

  static List<ProviderTotal> byProvider(List<RecurringExpense> expenses) {
    final total = _total(expenses);
    final groups = groupBy(expenses, (e) => e.name.trim().toLowerCase());
    return [
      for (final items in groups.values)
        ProviderTotal(
          name: items.first.name.trim(),
          categoryId: items.first.categoryId,
          yearly: _total(items),
          count: items.length,
          share: _share(_total(items), total),
        ),
    ]..sort((a, b) => b.yearly.compareTo(a.yearly));
  }

  static List<FrequencyTotal> byFrequency(List<RecurringExpense> expenses) {
    final total = _total(expenses);
    final groups = groupBy(expenses, (e) => e.cycle.frequency);
    return [
      for (final frequency in BillingFrequency.values)
        if (groups[frequency] case final items?)
          FrequencyTotal(
            frequency: frequency,
            yearly: _total(items),
            count: items.length,
            share: _share(_total(items), total),
          ),
    ];
  }

  static List<RecurringExpense> largest(List<RecurringExpense> expenses) =>
      expenses.sorted((a, b) =>
          CostCalculator.yearly(b).compareTo(CostCalculator.yearly(a)));

  /// Real cash-out per calendar month for the next [months] months,
  /// starting with the month containing [today] (from [today] onwards).
  static List<MonthProjection> monthlyProjection(
    List<RecurringExpense> expenses,
    DateTime today, {
    int months = 12,
  }) {
    final first = DateMath.startOfMonth(today);
    final end = DateMath.addDays(DateMath.addMonths(first, months), -1);
    final all = PaymentSchedule.occurrences(expenses, today, end);
    final byMonth = groupBy(all, (p) => DateMath.startOfMonth(p.date));
    return [
      for (var i = 0; i < months; i++)
        MonthProjection(
          DateMath.addMonths(first, i),
          byMonth[DateMath.addMonths(first, i)] ?? const [],
        ),
    ];
  }

  static double _total(Iterable<RecurringExpense> items) =>
      items.fold(0, (sum, e) => sum + CostCalculator.yearly(e));

  static double _share(double part, double total) => total == 0 ? 0 : part / total;
}
