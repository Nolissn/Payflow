import 'package:flutter/material.dart';

import 'app.dart';
import 'data/demo/demo_expenses.dart';
import 'data/repositories/in_memory_expense_repository.dart';
import 'state/expense_store.dart';
import 'state/settings_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Composition root: swap the repository here to move to Firebase /
  // Supabase. Nothing else in the app depends on the concrete backend.
  final settings = SettingsStore();
  final expenses = ExpenseStore(
    repository: InMemoryExpenseRepository(
      seed: buildDemoExpenses(DateTime.now()),
    ),
    settings: settings,
  )..load();

  runApp(PayflowApp(expenses: expenses, settings: settings));
}
