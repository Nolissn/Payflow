import 'package:payflow/core/utils/date_math.dart';
import 'package:payflow/domain/models/billing_cycle.dart';
import 'package:payflow/domain/models/category.dart';
import 'package:payflow/domain/models/expense_status.dart';
import 'package:payflow/domain/models/notice_period.dart';
import 'package:payflow/domain/models/recurring_expense.dart';

/// Realistic demo data. Dates are relative to [today] so the app always
/// shows a lively upcoming schedule, whenever it is opened.
List<RecurringExpense> buildDemoExpenses(DateTime today) {
  final t = DateMath.dateOnly(today);
  DateTime inDays(int days) => DateMath.addDays(t, days);
  DateTime yearsAgo(int years, int days) =>
      DateMath.addDays(DateMath.addMonths(t, -12 * years), days);

  RecurringExpense item(
    String id,
    String name,
    double amount,
    ExpenseCategory category,
    BillingCycle cycle,
    int nextInDays, {
    ExpenseStatus status = ExpenseStatus.active,
    NoticePeriod? notice,
    DateTime? start,
    DateTime? end,
    String? note,
    String? url,
  }) =>
      RecurringExpense(
        id: id,
        name: name,
        amount: amount,
        categoryId: category.id,
        cycle: cycle,
        nextPaymentDate: inDays(nextInDays),
        status: status,
        noticePeriod: notice,
        startDate: start,
        endDate: end,
        note: note,
        url: url,
        createdAt: t,
        updatedAt: t,
      );

  const days30 = NoticePeriod(30, NoticeUnit.day);
  const month1 = NoticePeriod(1, NoticeUnit.month);
  const months3 = NoticePeriod(3, NoticeUnit.month);

  return [
    item('netflix', 'Netflix', 13.99, DefaultCategories.streaming, BillingCycle.monthly, 1,
        start: yearsAgo(4, 1), url: 'https://www.netflix.com/youraccount',
        note: 'Standard plan, shared with family.'),
    item('spotify', 'Spotify', 11.99, DefaultCategories.streaming, BillingCycle.monthly, 4,
        start: yearsAgo(6, 4), url: 'https://www.spotify.com/account'),
    item('disney', 'Disney+', 9.99, DefaultCategories.streaming, BillingCycle.monthly, 12,
        start: yearsAgo(1, 12)),
    item('youtube', 'YouTube Premium', 12.00, DefaultCategories.streaming,
        BillingCycle.monthly, 18),
    item('gym', 'Gym', 29.99, DefaultCategories.fitness, BillingCycle.monthly, 10,
        notice: month1, start: yearsAgo(2, 10),
        note: 'Includes sauna. Minimum term ended.'),
    item('liability', 'Liability insurance', 240.00, DefaultCategories.insurance,
        BillingCycle.yearly, 24,
        notice: month1, start: yearsAgo(5, 24)),
    item('car', 'Car insurance', 456.00, DefaultCategories.insurance, BillingCycle.yearly, 52,
        notice: month1, note: 'Fully comprehensive, 35% no-claims class.'),
    item('household', 'Household insurance', 36.50, DefaultCategories.insurance,
        BillingCycle.quarterly, 33, notice: months3),
    item('jetbrains', 'JetBrains', 99.00, DefaultCategories.software, BillingCycle.yearly, 55,
        notice: days30, url: 'https://account.jetbrains.com'),
    item('notion', 'Notion Plus', 9.50, DefaultCategories.software, BillingCycle.monthly, 3,
        url: 'https://www.notion.so'),
    item('domain', 'Domain', 12.00, DefaultCategories.cloud, BillingCycle.yearly, 45,
        note: 'payflow.app'),
    item('icloud', 'iCloud+', 2.99, DefaultCategories.cloud, BillingCycle.monthly, 8),
    item('hetzner', 'Hetzner Cloud', 4.51, DefaultCategories.cloud, BillingCycle.monthly, 11),
    item('phone', 'Mobile plan', 19.99, DefaultCategories.telecom, BillingCycle.monthly, 6,
        notice: month1),
    item('internet', 'Home internet', 39.99, DefaultCategories.telecom, BillingCycle.monthly,
        14, notice: months3),
    item('transit', 'Transit pass', 58.00, DefaultCategories.transportation,
        BillingCycle.monthly, 10),
    item('bank', 'Bank account', 4.90, DefaultCategories.finance, BillingCycle.monthly, 9),
    item('card', 'Credit card fee', 39.00, DefaultCategories.finance, BillingCycle.yearly, 70),
    item('nintendo', 'Nintendo Switch Online', 19.99, DefaultCategories.gaming,
        BillingCycle.yearly, 38),
    item('gamepass', 'Xbox Game Pass', 14.99, DefaultCategories.gaming, BillingCycle.monthly,
        20, status: ExpenseStatus.paused),
    item('audible', 'Audible', 9.95, DefaultCategories.entertainment, BillingCycle.monthly, 5,
        status: ExpenseStatus.trial),
    item('kindle', 'Kindle Unlimited', 9.99, DefaultCategories.entertainment,
        BillingCycle.monthly, 16),
    item('coffee', 'Coffee beans', 8.50, DefaultCategories.other, BillingCycle.weekly, 2,
        note: 'Roaster delivery, 250 g.'),
    item('haircut', 'Haircut', 32.00, DefaultCategories.other,
        const BillingCycle(CycleUnit.week, 6), 27),
    item('prime', 'Amazon Prime', 89.90, DefaultCategories.streaming, BillingCycle.yearly, 64,
        status: ExpenseStatus.cancelled),
  ];
}
