import '../../core/utils/date_math.dart';
import '../models/recurring_expense.dart';

/// A single projected charge of a recurring expense.
class PaymentOccurrence {
  const PaymentOccurrence(this.expense, this.date);

  final RecurringExpense expense;
  final DateTime date;

  double get amount => expense.amount;
}

/// The next point in time a subscription must be cancelled by to avoid
/// being renewed.
class CancellationDeadline {
  const CancellationDeadline({
    required this.expense,
    required this.renewalDate,
    required this.deadline,
    required this.daysLeft,
  });

  final RecurringExpense expense;
  final DateTime renewalDate;
  final DateTime deadline;

  /// Days from today until [deadline] (0 = today is the last day).
  final int daysLeft;
}

/// Projects payment dates and cancellation deadlines from the expense data.
abstract final class PaymentSchedule {
  static const _maxIterations = 10000;

  /// All charge dates of [expense] within `[from, to]` (inclusive, date-only).
  ///
  /// The schedule is anchored at `nextPaymentDate` and honours the optional
  /// start and end dates. Status is *not* considered here.
  static Iterable<DateTime> datesBetween(
    RecurringExpense expense,
    DateTime from,
    DateTime to,
  ) sync* {
    final start = DateMath.dateOnly(from);
    final end = DateMath.dateOnly(to);
    final anchor = DateMath.dateOnly(expense.nextPaymentDate);
    final startDate =
        expense.startDate == null ? null : DateMath.dateOnly(expense.startDate!);
    final endDate =
        expense.endDate == null ? null : DateMath.dateOnly(expense.endDate!);

    for (var n = 0; n < _maxIterations; n++) {
      final date = expense.cycle.occurrence(anchor, n);
      if (date.isAfter(end)) return;
      if (endDate != null && date.isAfter(endDate)) return;
      if (date.isBefore(start)) continue;
      if (startDate != null && date.isBefore(startDate)) continue;
      yield date;
    }
  }

  /// The next charge on or after [from], or `null` if there is none
  /// (ended, paused or cancelled).
  static DateTime? nextPayment(RecurringExpense expense, DateTime from) {
    if (!expense.status.isBilled) return null;
    // Two years comfortably covers every realistic interval.
    final horizon = DateMath.addMonths(from, 24 + _cycleMonths(expense));
    final dates = datesBetween(expense, from, horizon);
    return dates.isEmpty ? null : dates.first;
  }

  /// All billed charges between [from] and [to], sorted chronologically.
  static List<PaymentOccurrence> occurrences(
    Iterable<RecurringExpense> expenses,
    DateTime from,
    DateTime to,
  ) {
    final result = <PaymentOccurrence>[
      for (final e in expenses)
        if (e.status.isBilled)
          for (final date in datesBetween(e, from, to)) PaymentOccurrence(e, date),
    ];
    result.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : b.amount.compareTo(a.amount);
    });
    return result;
  }

  /// The next cancellation deadline that has not passed yet, or `null` if
  /// the expense has no notice period or no further renewals.
  static CancellationDeadline? nextDeadline(
    RecurringExpense expense,
    DateTime today,
  ) {
    final notice = expense.noticePeriod;
    if (notice == null || !expense.status.isBilled) return null;
    final day = DateMath.dateOnly(today);
    final horizon = DateMath.addMonths(day, 36 + _cycleMonths(expense));
    for (final renewal in datesBetween(expense, day, horizon)) {
      final deadline = notice.latestCancellationFor(renewal);
      if (!deadline.isBefore(day)) {
        return CancellationDeadline(
          expense: expense,
          renewalDate: renewal,
          deadline: deadline,
          daysLeft: DateMath.daysBetween(day, deadline),
        );
      }
    }
    return null;
  }

  static int _cycleMonths(RecurringExpense e) =>
      (12 / e.cycle.occurrencesPerYear).ceil();
}
