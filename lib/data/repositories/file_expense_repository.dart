import '../../domain/models/category.dart';
import '../../domain/models/recurring_expense.dart';
import '../local/json_file.dart';
import 'expense_repository.dart';

/// Stores all expenses on the device as one JSON file.
class FileExpenseRepository implements ExpenseRepository {
  FileExpenseRepository(this._file);

  final JsonFile _file;
  Map<String, RecurringExpense>? _items;

  Future<Map<String, RecurringExpense>> _load() async {
    if (_items != null) return _items!;
    try {
      final json = await _file.read();
      final list = (json as Map<String, Object?>?)?['expenses'] as List? ?? [];
      final expenses = list
          .cast<Map<String, Object?>>()
          .map(RecurringExpense.fromJson);
      return _items = {for (final e in expenses) e.id: e};
    } catch (e) {
      throw RepositoryException('Your saved data could not be read ($e)');
    }
  }

  Future<void> _persist() async {
    try {
      await _file.write({
        'version': 1,
        'expenses': [for (final e in _items!.values) e.toJson()],
      });
    } catch (e) {
      throw RepositoryException('Could not save your data ($e)');
    }
  }

  @override
  Future<List<RecurringExpense>> fetchExpenses() async =>
      (await _load()).values.toList();

  @override
  Future<void> saveExpense(RecurringExpense expense) async {
    (await _load())[expense.id] = expense;
    await _persist();
  }

  @override
  Future<void> deleteExpense(String id) async {
    (await _load()).remove(id);
    await _persist();
  }

  @override
  Future<void> replaceAll(List<RecurringExpense> expenses) async {
    _items = {for (final e in expenses) e.id: e};
    await _persist();
  }

  @override
  Future<List<ExpenseCategory>> fetchCategories() async =>
      DefaultCategories.all;
}
