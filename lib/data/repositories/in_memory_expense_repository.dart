import '../../domain/models/category.dart';
import '../../domain/models/recurring_expense.dart';
import 'expense_repository.dart';

/// Keeps data in memory. Starts empty unless given a seed; simulates a short network
/// latency so loading states behave like they will with a real backend.
class InMemoryExpenseRepository implements ExpenseRepository {
  InMemoryExpenseRepository({
    List<RecurringExpense> seed = const [],
    this.latency = const Duration(milliseconds: 450),
  }) : _items = {for (final e in seed) e.id: e};

  final Duration latency;
  final Map<String, RecurringExpense> _items;

  Future<void> _delay() => Future.delayed(latency);

  @override
  Future<List<RecurringExpense>> fetchExpenses() async {
    await _delay();
    return _items.values.toList();
  }

  @override
  Future<void> saveExpense(RecurringExpense expense) async {
    _items[expense.id] = expense;
  }

  @override
  Future<void> deleteExpense(String id) async {
    _items.remove(id);
  }

  @override
  Future<void> replaceAll(List<RecurringExpense> expenses) async {
    _items
      ..clear()
      ..addEntries(expenses.map((e) => MapEntry(e.id, e)));
  }

  @override
  Future<List<ExpenseCategory>> fetchCategories() async => DefaultCategories.all;
}
