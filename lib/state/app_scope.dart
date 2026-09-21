import 'package:flutter/widgets.dart';

import '../core/formatting/money_format.dart';
import 'expense_store.dart';
import 'settings_store.dart';

/// Makes the app's stores available to the widget tree.
///
/// Widgets that call [ExpenseScope.of] / [SettingsScope.of] rebuild
/// automatically when the respective store notifies.
class AppScope extends StatelessWidget {
  const AppScope({
    super.key,
    required this.expenses,
    required this.settings,
    required this.child,
  });

  final ExpenseStore expenses;
  final SettingsStore settings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      notifier: settings,
      child: ExpenseScope(notifier: expenses, child: child),
    );
  }
}

class ExpenseScope extends InheritedNotifier<ExpenseStore> {
  const ExpenseScope({super.key, required super.notifier, required super.child});

  static ExpenseStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ExpenseScope>()!.notifier!;

  /// Access without subscribing to changes (for callbacks).
  static ExpenseStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ExpenseScope>()!.notifier!;
}

class SettingsScope extends InheritedNotifier<SettingsStore> {
  const SettingsScope({super.key, required super.notifier, required super.child});

  static SettingsStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;

  static SettingsStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}

extension AppScopeContext on BuildContext {
  ExpenseStore get store => ExpenseScope.of(this);
  SettingsStore get settings => SettingsScope.of(this);
  MoneyFormat get money => SettingsScope.of(this).money;
}
