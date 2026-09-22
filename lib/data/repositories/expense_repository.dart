import '../../domain/models/category.dart';
import '../../domain/models/recurring_expense.dart';

/// Thrown by repositories when data cannot be loaded or saved.
class RepositoryException implements Exception {
  const RepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Storage boundary for recurring expenses.
///
/// The app only talks to this interface. Swapping the in-memory
/// implementation for a Firebase, Supabase or local-database backed one
/// requires no changes to state management or UI code.
abstract interface class ExpenseRepository {
  Future<List<RecurringExpense>> fetchExpenses();

  /// Inserts or replaces the expense with the same id.
  Future<void> saveExpense(RecurringExpense expense);

  Future<void> deleteExpense(String id);

  /// Replaces the whole data set (used for "delete all data" / imports).
  Future<void> replaceAll(List<RecurringExpense> expenses);

  Future<List<ExpenseCategory>> fetchCategories();
}
