enum ExpenseStatus {
  active('Active'),
  trial('Trial'),
  paused('Paused'),
  cancelled('Cancelled');

  const ExpenseStatus(this.label);
  final String label;

  /// Whether expenses in this status are charged and count towards totals.
  bool get isBilled => this == active || this == trial;
}
