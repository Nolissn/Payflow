import '../models/recurring_expense.dart';
import 'payment_schedule.dart';

/// A reminder that an upcoming charge is due in [daysBefore] days.
class PaymentReminder {
  const PaymentReminder({
    required this.expense,
    required this.paymentDate,
    required this.daysBefore,
    required this.fireAt,
  });

  final RecurringExpense expense;
  final DateTime paymentDate;
  final int daysBefore;

  /// Local wall-clock time the reminder should be shown.
  final DateTime fireAt;

  double get amount => expense.amount;
}

/// Plans reminders 7 days, 3 days and 1 day (24 h) before every charge.
abstract final class PaymentReminders {
  static const leadDays = [7, 3, 1];

  /// Reminders are shown at this local hour on their day.
  static const hour = 9;

  /// iOS keeps at most 64 pending notifications, so only the nearest ones
  /// are planned. They are replanned every time the app opens.
  static const maxPending = 60;

  /// All reminders that fire after [now], soonest first, at most
  /// [maxPending].
  static List<PaymentReminder> plan(
    Iterable<RecurringExpense> expenses,
    DateTime now,
  ) {
    final from = DateTime(now.year, now.month, now.day);
    // Covers every lead time plus a generous window to fill [maxPending].
    final to = from.add(const Duration(days: 90));
    final reminders = <PaymentReminder>[
      for (final occurrence in PaymentSchedule.occurrences(expenses, from, to))
        for (final days in leadDays)
          if (_fireAt(occurrence.date, days) case final fireAt
              when fireAt.isAfter(now))
            PaymentReminder(
              expense: occurrence.expense,
              paymentDate: occurrence.date,
              daysBefore: days,
              fireAt: fireAt,
            ),
    ]..sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return reminders.take(maxPending).toList();
  }

  static DateTime _fireAt(DateTime paymentDate, int daysBefore) => DateTime(
      paymentDate.year, paymentDate.month, paymentDate.day - daysBefore, hour);
}
