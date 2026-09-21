import '../../core/utils/date_math.dart';

enum NoticeUnit {
  day,
  week,
  month;

  String label(int count) {
    final singular = name;
    return count == 1 ? singular : '${singular}s';
  }
}

/// A cancellation notice period, e.g. "30 days" or "3 months".
class NoticePeriod {
  const NoticePeriod(this.count, this.unit) : assert(count >= 0);

  final int count;
  final NoticeUnit unit;

  /// The latest day a cancellation must be submitted to stop a renewal on
  /// [renewal]. Example: renewal Nov 15, 30 days notice → Oct 16.
  DateTime latestCancellationFor(DateTime renewal) => switch (unit) {
        NoticeUnit.day => DateMath.addDays(renewal, -count),
        NoticeUnit.week => DateMath.addDays(renewal, -count * 7),
        NoticeUnit.month => DateMath.addMonths(renewal, -count),
      };

  String get label => '$count ${unit.label(count)}';

  Map<String, Object?> toJson() => {'count': count, 'unit': unit.name};

  factory NoticePeriod.fromJson(Map<String, Object?> json) => NoticePeriod(
        (json['count']! as num).toInt(),
        NoticeUnit.values.byName(json['unit']! as String),
      );

  @override
  bool operator ==(Object other) =>
      other is NoticePeriod && other.count == count && other.unit == unit;

  @override
  int get hashCode => Object.hash(count, unit);
}
