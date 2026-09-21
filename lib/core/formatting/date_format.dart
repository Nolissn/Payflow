import 'package:intl/intl.dart';

import '../utils/date_math.dart';

abstract final class Dates {
  static final _short = DateFormat('MMM d', 'en_US');
  static final _shortYear = DateFormat('MMM d, y', 'en_US');
  static final _weekday = DateFormat('EEE, MMM d', 'en_US');
  static final _long = DateFormat('MMMM d', 'en_US');
  static final _full = DateFormat('EEEE, MMMM d', 'en_US');
  static final _month = DateFormat('MMMM', 'en_US');
  static final _monthYear = DateFormat('MMMM y', 'en_US');
  static final _monthShort = DateFormat('MMM', 'en_US');
  static final _day = DateFormat('d', 'en_US');
  static final _weekdayShort = DateFormat('EEE', 'en_US');

  /// "Sep 22" (adds the year if it differs from [reference]'s year).
  static String short(DateTime d, {DateTime? reference}) =>
      reference != null && d.year != reference.year
          ? _shortYear.format(d)
          : _short.format(d);

  static String withYear(DateTime d) => _shortYear.format(d);
  static String weekday(DateTime d) => _weekday.format(d);
  static String long(DateTime d) => _long.format(d);
  static String full(DateTime d) => _full.format(d);
  static String month(DateTime d) => _month.format(d);
  static String monthYear(DateTime d) => _monthYear.format(d);
  static String monthShort(DateTime d) => _monthShort.format(d);
  static String day(DateTime d) => _day.format(d);
  static String weekdayShort(DateTime d) => _weekdayShort.format(d);

  /// "Today", "Tomorrow", "In 5 days", "In 3 weeks", "Yesterday", …
  static String relative(DateTime date, DateTime today) {
    final days = DateMath.daysBetween(today, date);
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days == -1) return 'Yesterday';
    if (days < 0) return '${-days} days ago';
    if (days < 14) return 'In $days days';
    if (days < 60) return 'In ${(days / 7).round()} weeks';
    return 'In ${(days / 30.4).round()} months';
  }
}
