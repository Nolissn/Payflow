import '../../core/utils/date_math.dart';

/// The time unit a [BillingCycle] is expressed in.
enum CycleUnit {
  day,
  week,
  month,
  year;

  /// How many of this unit fit into one (average) year.
  double get perYear => switch (this) {
        CycleUnit.day => 365,
        CycleUnit.week => 365 / 7,
        CycleUnit.month => 12,
        CycleUnit.year => 1,
      };

  String label(int count) {
    final singular = switch (this) {
      CycleUnit.day => 'day',
      CycleUnit.week => 'week',
      CycleUnit.month => 'month',
      CycleUnit.year => 'year',
    };
    return count == 1 ? singular : '${singular}s';
  }
}

/// The payment interval presets offered to the user.
enum BillingFrequency {
  weekly('Weekly'),
  monthly('Monthly'),
  quarterly('Quarterly'),
  yearly('Yearly'),
  custom('Custom');

  const BillingFrequency(this.label);
  final String label;
}

/// How often a recurring expense is charged, e.g. "every 1 month" or
/// "every 6 weeks". Presets are just well-known combinations of
/// [unit] and [count], so all calculations work the same way for custom
/// intervals.
class BillingCycle {
  const BillingCycle(this.unit, [this.count = 1]) : assert(count > 0);

  final CycleUnit unit;
  final int count;

  static const weekly = BillingCycle(CycleUnit.week);
  static const monthly = BillingCycle(CycleUnit.month);
  static const quarterly = BillingCycle(CycleUnit.month, 3);
  static const yearly = BillingCycle(CycleUnit.year);

  static BillingCycle fromFrequency(BillingFrequency frequency) =>
      switch (frequency) {
        BillingFrequency.weekly => weekly,
        BillingFrequency.monthly => monthly,
        BillingFrequency.quarterly => quarterly,
        BillingFrequency.yearly => yearly,
        BillingFrequency.custom => const BillingCycle(CycleUnit.month, 2),
      };

  BillingFrequency get frequency {
    if (this == weekly) return BillingFrequency.weekly;
    if (this == monthly) return BillingFrequency.monthly;
    if (this == quarterly) return BillingFrequency.quarterly;
    if (this == yearly) return BillingFrequency.yearly;
    return BillingFrequency.custom;
  }

  /// Average number of charges per year.
  double get occurrencesPerYear => unit.perYear / count;

  /// Returns the [n]-th occurrence after [anchor] (n = 0 is the anchor).
  ///
  /// Always computed from the anchor to avoid month-end drift: a cycle
  /// anchored on Jan 31 yields Feb 28, Mar 31, Apr 30, …
  DateTime occurrence(DateTime anchor, int n) {
    final steps = n * count;
    return switch (unit) {
      CycleUnit.day => DateMath.addDays(anchor, steps),
      CycleUnit.week => DateMath.addDays(anchor, steps * 7),
      CycleUnit.month => DateMath.addMonths(anchor, steps),
      CycleUnit.year => DateMath.addMonths(anchor, steps * 12),
    };
  }

  /// Short label used next to prices: "month", "year", "6 weeks".
  String get perLabel => count == 1 ? unit.label(1) : '$count ${unit.label(count)}';

  /// Human label: "Monthly", "Every 6 weeks".
  String get label => frequency == BillingFrequency.custom
      ? 'Every $count ${unit.label(count)}'
      : frequency.label;

  Map<String, Object?> toJson() => {'unit': unit.name, 'count': count};

  factory BillingCycle.fromJson(Map<String, Object?> json) => BillingCycle(
        CycleUnit.values.byName(json['unit']! as String),
        (json['count'] as num?)?.toInt() ?? 1,
      );

  @override
  bool operator ==(Object other) =>
      other is BillingCycle && other.unit == unit && other.count == count;

  @override
  int get hashCode => Object.hash(unit, count);

  @override
  String toString() => 'BillingCycle($count ${unit.name})';
}
