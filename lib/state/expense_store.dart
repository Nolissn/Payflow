import 'package:flutter/foundation.dart';

import '../core/formatting/date_format.dart';
import '../data/repositories/expense_repository.dart';
import '../domain/models/category.dart';
import '../domain/models/expense_status.dart';
import '../domain/models/recurring_expense.dart';
import '../domain/services/finance_overview.dart';
import '../domain/services/insights_engine.dart';
import 'settings_store.dart';

enum LoadStatus { loading, ready, error }

/// App state for recurring expenses.
///
/// Owns the list of expenses, talks to the [ExpenseRepository] and exposes a
/// cached [FinanceOverview] that screens read derived numbers from.
class ExpenseStore extends ChangeNotifier {
  ExpenseStore({
    required this._repository,
    required this._settings,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _settings.addListener(_onSettingsChanged);
  }

  final ExpenseRepository _repository;
  final SettingsStore _settings;
  final DateTime Function() _clock;

  LoadStatus _status = LoadStatus.loading;
  String? _error;
  List<RecurringExpense> _expenses = const [];
  List<ExpenseCategory> _categories = DefaultCategories.all;
  FinanceOverview? _overview;

  LoadStatus get status => _status;
  String? get error => _error;
  List<RecurringExpense> get expenses => _expenses;
  List<ExpenseCategory> get categories => _categories;
  bool get isEmpty => _expenses.isEmpty;

  DateTime get today => _clock();

  FinanceOverview get overview => _overview ??= FinanceOverview(
        expenses: _expenses,
        categories: _categories,
        today: today,
        largePaymentThreshold: _settings.largePaymentThreshold,
        insightsEngine: InsightsEngine(
          money: _settings.money.call,
          date: Dates.long,
        ),
      );

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.fetchExpenses(),
        _repository.fetchCategories(),
      ]);
      _expenses = results[0] as List<RecurringExpense>;
      _categories = results[1] as List<ExpenseCategory>;
      _status = LoadStatus.ready;
    } catch (e) {
      _error = e.toString();
      _status = LoadStatus.error;
    }
    _changed();
  }

  /// Adds a new expense or replaces an existing one (optimistic update).
  Future<void> save(RecurringExpense expense) async {
    final now = _clock();
    final exists = _expenses.any((e) => e.id == expense.id);
    final stamped = expense.copyWith(
      createdAt: expense.createdAt ?? now,
      updatedAt: now,
    );
    final previous = _expenses;
    _expenses = exists
        ? [for (final e in _expenses) e.id == expense.id ? stamped : e]
        : [..._expenses, stamped];
    _changed();
    try {
      await _repository.saveExpense(stamped);
    } catch (_) {
      _expenses = previous;
      _changed();
      rethrow;
    }
  }

  /// Removes an expense and returns it so the UI can offer "Undo".
  Future<RecurringExpense?> delete(String id) async {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index < 0) return null;
    final removed = _expenses[index];
    _expenses = [..._expenses]..removeAt(index);
    _changed();
    try {
      await _repository.deleteExpense(id);
    } catch (_) {
      _expenses = [..._expenses]..insert(index, removed);
      _changed();
      rethrow;
    }
    return removed;
  }

  Future<void> setStatus(String id, ExpenseStatus status) async {
    final expense = _expenses.where((e) => e.id == id).firstOrNull;
    if (expense == null) return;
    await save(expense.copyWith(status: status));
  }

  Future<void> clearAll() async {
    await _repository.replaceAll(const []);
    _expenses = const [];
    _changed();
  }

  /// Recomputes date-dependent values (e.g. after the app resumes on a new day).
  void refreshDay() => _changed();

  void _onSettingsChanged() => _changed();

  void _changed() {
    _overview = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
