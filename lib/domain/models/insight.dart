enum InsightKind {
  categoryCluster,
  mostExpensive,
  upcomingYearly,
  deadlineSoon,
  trialEnding,
  smallAddUp,
  concentration,
  pausedSavings,
}

/// How much an insight asks for the user's attention. Insights never
/// recommend an action — they only surface facts worth reviewing.
enum InsightTone { neutral, attention }

class Insight {
  const Insight({
    required this.kind,
    required this.title,
    required this.message,
    this.tone = InsightTone.neutral,
    this.expenseIds = const [],
    this.categoryId,
  });

  final InsightKind kind;
  final String title;
  final String message;
  final InsightTone tone;

  /// Expenses the insight refers to (used for "review" links).
  final List<String> expenseIds;
  final String? categoryId;
}
