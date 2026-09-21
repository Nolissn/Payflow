/// Calendar arithmetic on date-only values.
///
/// All helpers work on local calendar dates (time of day is dropped) and use
/// the `DateTime(y, m, d)` constructor so they are immune to DST shifts.
abstract final class DateMath {
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  /// Adds [months], clamping the day to the target month's length
  /// (Jan 31 + 1 month → Feb 28/29).
  static DateTime addMonths(DateTime d, int months) {
    final monthIndex = d.month - 1 + months;
    final year = d.year + (monthIndex / 12).floor();
    final month = monthIndex % 12 + 1;
    final day = d.day.clamp(1, daysInMonth(year, month));
    return DateTime(year, month, day);
  }

  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// Whole calendar days from [from] to [to] (negative if [to] is earlier).
  static int daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day)
          .difference(DateTime.utc(from.year, from.month, from.day))
          .inDays;

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);
}
