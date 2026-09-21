import '../models/billing_cycle.dart';
import '../models/recurring_expense.dart';

/// The period a normalised cost is expressed in.
enum CostPeriod {
  day('day', 'Daily'),
  week('week', 'Weekly'),
  month('month', 'Monthly'),
  year('year', 'Yearly');

  const CostPeriod(this.unitLabel, this.label);
  final String unitLabel;
  final String label;

  double get perYear => switch (this) {
        CostPeriod.day => 365,
        CostPeriod.week => 365 / 7,
        CostPeriod.month => 12,
        CostPeriod.year => 1,
      };
}

/// Aggregated costs of a set of expenses, normalised to common periods.
class CostSummary {
  const CostSummary({required this.yearly, required this.count});

  static const zero = CostSummary(yearly: 0, count: 0);

  final double yearly;
  final int count;

  double get monthly => yearly / 12;
  double get weekly => yearly / CostPeriod.week.perYear;
  double get daily => yearly / 365;

  double inPeriod(CostPeriod period) => yearly / period.perYear;
}

/// The single source of truth for converting between payment intervals.
///
/// Every conversion goes through the yearly amount: a charge is first
/// multiplied by how often it occurs per year, then divided into the target
/// period. €12 monthly → €144 yearly; €120 yearly → €10 monthly;
/// €30 weekly → €1,564.29 yearly → €130.36 monthly.
abstract final class CostCalculator {
  static double yearlyAmount(double amount, BillingCycle cycle) =>
      amount * cycle.occurrencesPerYear;

  static double convert(double amount, BillingCycle cycle, CostPeriod to) =>
      yearlyAmount(amount, cycle) / to.perYear;

  static double yearly(RecurringExpense e) => yearlyAmount(e.amount, e.cycle);
  static double monthly(RecurringExpense e) => yearly(e) / 12;
  static double daily(RecurringExpense e) => yearly(e) / 365;
  static double inPeriod(RecurringExpense e, CostPeriod period) =>
      yearly(e) / period.perYear;

  static CostSummary summarize(Iterable<RecurringExpense> expenses) {
    var total = 0.0;
    var count = 0;
    for (final e in expenses) {
      total += yearly(e);
      count++;
    }
    return CostSummary(yearly: total, count: count);
  }
}
