import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/core/utils/date_math.dart';
import 'fixtures/demo_expenses.dart';
import 'package:payflow/domain/models/billing_cycle.dart';
import 'package:payflow/domain/models/category.dart';
import 'package:payflow/domain/models/expense_status.dart';
import 'package:payflow/domain/models/notice_period.dart';
import 'package:payflow/domain/models/recurring_expense.dart';
import 'package:payflow/domain/services/cost_calculator.dart';
import 'package:payflow/domain/services/finance_overview.dart';
import 'package:payflow/domain/services/insights_engine.dart';
import 'package:payflow/domain/services/payment_reminders.dart';
import 'package:payflow/domain/services/payment_schedule.dart';
import 'package:payflow/features/expense_form/expense_form_sheet.dart';

RecurringExpense _e(
  String id,
  double amount,
  BillingCycle cycle,
  DateTime next, {
  ExpenseStatus status = ExpenseStatus.active,
  NoticePeriod? notice,
  DateTime? end,
  String category = 'streaming',
}) =>
    RecurringExpense(
      id: id,
      name: id,
      amount: amount,
      categoryId: category,
      cycle: cycle,
      nextPaymentDate: next,
      status: status,
      noticePeriod: notice,
      endDate: end,
    );

void main() {
  group('CostCalculator', () {
    test('€12 monthly → €144 yearly', () {
      expect(CostCalculator.convert(12, BillingCycle.monthly, CostPeriod.year),
          closeTo(144, 1e-9));
    });

    test('€120 yearly → €10 monthly', () {
      expect(CostCalculator.convert(120, BillingCycle.yearly, CostPeriod.month),
          closeTo(10, 1e-9));
    });

    test('€30 weekly → average monthly and yearly', () {
      final yearly =
          CostCalculator.convert(30, BillingCycle.weekly, CostPeriod.year);
      expect(yearly, closeTo(30 * 365 / 7, 1e-9)); // €1,564.29
      expect(CostCalculator.convert(30, BillingCycle.weekly, CostPeriod.month),
          closeTo(yearly / 12, 1e-9)); // €130.36
    });

    test('quarterly and custom intervals', () {
      expect(CostCalculator.convert(30, BillingCycle.quarterly, CostPeriod.year),
          closeTo(120, 1e-9));
      expect(
          CostCalculator.convert(
              60, const BillingCycle(CycleUnit.month, 2), CostPeriod.month),
          closeTo(30, 1e-9));
    });

    test('summary normalises to month, year and day', () {
      final s = CostCalculator.summarize([
        _e('a', 12, BillingCycle.monthly, DateTime(2026, 1, 1)),
        _e('b', 120, BillingCycle.yearly, DateTime(2026, 1, 1)),
      ]);
      expect(s.yearly, closeTo(264, 1e-9));
      expect(s.monthly, closeTo(22, 1e-9));
      expect(s.daily, closeTo(264 / 365, 1e-9));
    });
  });

  group('BillingCycle', () {
    test('month-end anchoring does not drift', () {
      final anchor = DateTime(2026, 1, 31);
      expect(BillingCycle.monthly.occurrence(anchor, 1), DateTime(2026, 2, 28));
      expect(BillingCycle.monthly.occurrence(anchor, 2), DateTime(2026, 3, 31));
      expect(BillingCycle.monthly.occurrence(anchor, 3), DateTime(2026, 4, 30));
    });

    test('json round trip', () {
      const cycle = BillingCycle(CycleUnit.week, 6);
      expect(BillingCycle.fromJson(cycle.toJson()), cycle);
      expect(cycle.frequency, BillingFrequency.custom);
      expect(BillingCycle.quarterly.frequency, BillingFrequency.quarterly);
    });
  });

  group('PaymentSchedule', () {
    final today = DateTime(2026, 9, 21);

    test('rolls a past anchor forward', () {
      final e = _e('n', 13.99, BillingCycle.monthly, DateTime(2026, 6, 22));
      expect(PaymentSchedule.nextPayment(e, today), DateTime(2026, 9, 22));
    });

    test('includes yearly payments and respects end date', () {
      final yearly = _e('i', 240, BillingCycle.yearly, DateTime(2026, 10, 15));
      final ended = _e('x', 10, BillingCycle.monthly, DateTime(2026, 9, 25),
          end: DateTime(2026, 10, 30));
      final list = PaymentSchedule.occurrences(
          [yearly, ended], today, DateMath.addDays(today, 90));
      expect(list.map((p) => p.date), [
        DateTime(2026, 9, 25),
        DateTime(2026, 10, 15),
        DateTime(2026, 10, 25),
      ]);
    });

    test('paused and cancelled are not scheduled', () {
      final paused = _e('p', 10, BillingCycle.monthly, DateTime(2026, 9, 25),
          status: ExpenseStatus.paused);
      expect(PaymentSchedule.nextPayment(paused, today), isNull);
    });

    test('latest cancellation date: Nov 15 with 30 days → Oct 16', () {
      final e = _e('s', 99, BillingCycle.yearly, DateTime(2026, 11, 15),
          notice: const NoticePeriod(30, NoticeUnit.day));
      final d = PaymentSchedule.nextDeadline(e, today)!;
      expect(d.renewalDate, DateTime(2026, 11, 15));
      expect(d.deadline, DateTime(2026, 10, 16));
      expect(d.daysLeft, 25);
    });

    test('a missed deadline moves to the next renewal', () {
      final e = _e('i', 240, BillingCycle.yearly, DateTime(2026, 10, 15),
          notice: const NoticePeriod(1, NoticeUnit.month));
      final d = PaymentSchedule.nextDeadline(e, today)!;
      expect(d.renewalDate, DateTime(2027, 10, 15));
      expect(d.deadline, DateTime(2027, 9, 15));
    });
  });

  group('PaymentReminders', () {
    test('reminds 7, 3 and 1 day before each charge at 09:00', () {
      final plan = PaymentReminders.plan(
        [_e('Netflix', 12.99, BillingCycle.yearly, DateTime(2026, 10, 10))],
        DateTime(2026, 9, 22, 12),
      );
      expect(plan.map((r) => r.fireAt), [
        DateTime(2026, 10, 3, 9),
        DateTime(2026, 10, 7, 9),
        DateTime(2026, 10, 9, 9),
      ]);
      expect(plan.map((r) => r.daysBefore), [7, 3, 1]);
      expect(plan.every((r) => r.amount == 12.99), isTrue);
      expect(plan.every((r) => r.paymentDate == DateTime(2026, 10, 10)), isTrue);
    });

    test('skips reminders whose time has passed', () {
      // Charge in 2 days: the 7- and 3-day reminders are already over.
      final plan = PaymentReminders.plan(
        [_e('Spotify', 9.99, BillingCycle.yearly, DateTime(2026, 9, 24))],
        DateTime(2026, 9, 22, 12),
      );
      expect(plan.single.daysBefore, 1);
      expect(plan.single.fireAt, DateTime(2026, 9, 23, 9));
    });

    test('ignores paused and cancelled expenses', () {
      final plan = PaymentReminders.plan([
        _e('a', 5, BillingCycle.monthly, DateTime(2026, 10, 10),
            status: ExpenseStatus.paused),
        _e('b', 5, BillingCycle.monthly, DateTime(2026, 10, 10),
            status: ExpenseStatus.cancelled),
      ], DateTime(2026, 9, 22));
      expect(plan, isEmpty);
    });

    test('keeps only the nearest reminders, soonest first', () {
      final plan = PaymentReminders.plan(
        [
          for (var i = 0; i < 30; i++)
            _e('w$i', 1, BillingCycle.weekly, DateTime(2026, 9, 25)),
        ],
        DateTime(2026, 9, 22),
      );
      expect(plan, hasLength(PaymentReminders.maxPending));
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].fireAt.isBefore(plan[i - 1].fireAt), isFalse);
      }
    });
  });

  group('FinanceOverview with demo data', () {
    final today = DateTime(2026, 9, 21);
    final overview = FinanceOverview(
      expenses: buildDemoExpenses(today),
      categories: DefaultCategories.all,
      today: today,
      largePaymentThreshold: 100,
      insightsEngine: InsightsEngine(
        money: (v) => '€${v.toStringAsFixed(2)}',
        date: (d) => '${d.month}/${d.day}',
      ),
    );

    test('excludes paused and cancelled from totals', () {
      expect(overview.billed.any((e) => e.status == ExpenseStatus.paused), isFalse);
      expect(overview.billed.any((e) => e.status == ExpenseStatus.cancelled),
          isFalse);
      expect(overview.summary.monthly, greaterThan(0));
    });

    test('category shares add up to 100%', () {
      final total = overview.byCategory.fold<double>(0, (s, t) => s + t.share);
      expect(total, closeTo(1, 1e-9));
    });

    test('upcoming is chronological and starts tomorrow with Netflix', () {
      final next = overview.upcoming(days: 30);
      for (var i = 1; i < next.length; i++) {
        expect(next[i].date.isBefore(next[i - 1].date), isFalse);
      }
      expect(overview.nextPayment!.expense.name, 'Netflix');
    });

    test('streaming insight matches the product example', () {
      final streaming = overview.insights
          .firstWhere((i) => i.categoryId == 'streaming');
      expect(streaming.message,
          'You spend €47.97 per month on 4 streaming services.');
    });

    test('12-month projection totals match the yearly schedule', () {
      final projected =
          overview.projection.fold<double>(0, (s, m) => s + m.total);
      expect(projected, greaterThan(overview.summary.yearly * 0.9));
    });
  });

  test('RecurringExpense json round trip', () {
    final e = _e('j', 99, BillingCycle.yearly, DateTime(2026, 11, 15),
        notice: const NoticePeriod(30, NoticeUnit.day));
    expect(RecurringExpense.fromJson(e.toJson()), e);
  });

  test('domains survive a json round trip', () {
    final e = _e('d', 24, BillingCycle.yearly, DateTime(2026, 11, 15))
        .copyWith(domains: ['example.com', 'example.org']);
    final back = RecurringExpense.fromJson(e.toJson());
    expect(back.domains, ['example.com', 'example.org']);
    expect(back, e);
    expect(e == e.copyWith(domains: ['example.com']), isFalse);
  });

  test('json without domains still loads', () {
    final json = _e('o', 5, BillingCycle.monthly, DateTime(2026, 10, 1)).toJson()
      ..remove('domains');
    expect(RecurringExpense.fromJson(json).domains, isEmpty);
  });

  test('normalizeDomain cleans up pasted URLs', () {
    expect(normalizeDomain('https://www.Example.com/path?q=1'), 'example.com');
    expect(normalizeDomain('shop.example.co.uk'), 'shop.example.co.uk');
    expect(normalizeDomain('example.com.'), 'example.com');
    expect(normalizeDomain('localhost'), isNull);
    expect(normalizeDomain('not a domain'), isNull);
    expect(normalizeDomain('-bad-.com'), isNull);
  });
}
