import 'package:flutter/widgets.dart';

import '../core/formatting/money_format.dart';
import '../data/backup/backup_service.dart';
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
    this.backups,
    required this.child,
  });

  final ExpenseStore expenses;
  final SettingsStore settings;
  final BackupService? backups;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BackupScope(
      backups: backups,
      child: SettingsScope(
        notifier: settings,
        child: ExpenseScope(notifier: expenses, child: child),
      ),
    );
  }
}

class BackupScope extends InheritedWidget {
  const BackupScope({super.key, required this.backups, required super.child});

  final BackupService? backups;

  /// `null` when backups aren't available (e.g. in tests).
  static BackupService? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BackupScope>()?.backups;

  @override
  bool updateShouldNotify(BackupScope oldWidget) =>
      backups != oldWidget.backups;
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
