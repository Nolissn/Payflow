import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/app.dart';
import 'package:payflow/data/backup/backup_service.dart';
import 'fixtures/demo_expenses.dart';
import 'package:payflow/data/repositories/expense_repository.dart';
import 'package:payflow/data/repositories/in_memory_expense_repository.dart';
import 'package:payflow/domain/models/category.dart';
import 'package:payflow/domain/models/recurring_expense.dart';
import 'package:payflow/features/expense_detail/expense_detail_screen.dart';
import 'package:payflow/features/expense_form/expense_form_sheet.dart';
import 'package:payflow/features/life_cost/life_cost_screen.dart';
import 'package:payflow/features/settings/settings_screen.dart';
import 'package:payflow/state/expense_store.dart';
import 'package:payflow/state/settings_store.dart';

final _today = DateTime(2026, 9, 21, 9);

Future<ExpenseStore> _pumpApp(
  WidgetTester tester, {
  ExpenseRepository? repository,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final settings = SettingsStore();
  final store = ExpenseStore(
    repository: repository ??
        InMemoryExpenseRepository(
            seed: buildDemoExpenses(_today), latency: Duration.zero),
    settings: settings,
    clock: () => _today,
  );
  await tester.runAsync(store.load);
  await tester.pumpWidget(PayflowApp(expenses: store, settings: settings));
  await tester.pumpAndSettle();
  return store;
}

/// Lets real file I/O finish (it can't run inside the fake test clock).
Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(finder, findsOneWidget);
}

class _FailingRepository implements ExpenseRepository {
  @override
  Future<List<RecurringExpense>> fetchExpenses() =>
      Future.error(const RepositoryException('Network unavailable'));
  @override
  Future<List<ExpenseCategory>> fetchCategories() async => DefaultCategories.all;
  @override
  Future<void> saveExpense(RecurringExpense expense) async {}
  @override
  Future<void> deleteExpense(String id) async {}
  @override
  Future<void> replaceAll(List<RecurringExpense> expenses) async {}
}

void main() {
  testWidgets('dashboard shows the key metrics', (tester) async {
    final store = await _pumpApp(tester);
    final monthly = store.overview.summary.monthly;
    expect(find.text('MONTHLY COST'), findsOneWidget);
    expect(find.text('Yearly cost'), findsOneWidget);
    expect(find.text('Average per day'), findsOneWidget);
    expect(find.text('Next payment'), findsOneWidget);
    expect(monthly, greaterThan(0));
  });

  testWidgets('adding an expense updates the totals', (tester) async {
    final store = await _pumpApp(tester);
    final before = store.overview.summary.yearly;

    await tester.tap(find.byTooltip('Add recurring expense'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name or provider'), 'Climbing gym');
    await tester.enterText(find.widgetWithText(TextFormField, 'Price'), '10');
    await tester.tap(find.text('Yearly'));
    await tester.pump();
    expect(find.textContaining('€0.83 / month'), findsOneWidget);

    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();

    expect(find.text('Climbing gym added'), findsOneWidget);
    expect(store.overview.summary.yearly, closeTo(before + 10, 1e-9));
  });

  testWidgets('adding domains under a registrar', (tester) async {
    final store = await _pumpApp(tester);

    await tester.tap(find.byTooltip('Add recurring expense'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name or provider'), 'Porkbun');
    await tester.enterText(find.widgetWithText(TextFormField, 'Price'), '30');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Domain'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Domain'));
    await tester.pumpAndSettle();

    final domainInput = find.widgetWithText(TextField, 'example.com, example.org');
    await tester.enterText(domainInput, 'https://www.Alpha.com/, beta.dev');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'alpha.com'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'beta.dev'), findsOneWidget);

    await tester.enterText(domainInput, 'gamma.io');
    await tester.ensureVisible(find.text('Add expense'));
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();

    final saved = store.expenses.singleWhere((e) => e.name == 'Porkbun');
    expect(saved.categoryId, DefaultCategories.domain.id);
    expect(saved.cycle.label, 'Yearly');
    expect(saved.domains, ['alpha.com', 'beta.dev', 'gamma.io']);

    await tester.tap(find.text('Subscriptions').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'beta');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Porkbun'));
    await tester.pumpAndSettle();
    expect(find.text('3 domains'), findsOneWidget);
    expect(find.text('gamma.io'), findsOneWidget);
  });

  testWidgets('domain category needs at least one domain', (tester) async {
    final store = await _pumpApp(tester);
    final count = store.expenses.length;
    await tester.tap(find.byTooltip('Add recurring expense'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name or provider'), 'Porkbun');
    await tester.enterText(find.widgetWithText(TextFormField, 'Price'), '30');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Domain'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Domain'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add expense'));
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    expect(find.text('Add at least one domain'), findsOneWidget);
    expect(store.expenses.length, count);
  });

  testWidgets('settings opens backups and creates one', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('payflow_ui')))!;
    addTearDown(() => dir.deleteSync(recursive: true));
    final settings = SettingsStore();
    final store = ExpenseStore(
      repository: InMemoryExpenseRepository(
          seed: buildDemoExpenses(_today), latency: Duration.zero),
      settings: settings,
      clock: () => _today,
    );
    await tester.runAsync(store.load);
    final backups = BackupService(
        expenses: store, settings: settings, defaultDirectory: () async => dir);
    await tester.pumpWidget(
        PayflowApp(expenses: store, settings: settings, backups: backups));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Backups'), 200);
    await tester.tap(find.text('Backups'));
    await _pumpUntil(tester, find.text('No backups yet'));
    await tester.scrollUntilVisible(find.text('Change folder'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Default folder'), findsOneWidget);
    expect(find.text('Use default folder'), findsNothing);
    await tester.scrollUntilVisible(find.text('Back up now'), -200,
        scrollable: find.byType(Scrollable).last);

    await tester.tap(find.text('Back up now'));
    await _pumpUntil(tester, find.textContaining('Backup saved'));
    expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
  });

  testWidgets('validation blocks an empty form', (tester) async {
    final store = await _pumpApp(tester);
    final count = store.expenses.length;
    await tester.tap(find.byTooltip('Add recurring expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    expect(find.text('Give it a name'), findsOneWidget);
    expect(find.text('Enter a price'), findsOneWidget);
    expect(store.expenses.length, count);
  });

  testWidgets('deleting asks for confirmation and supports undo',
      (tester) async {
    final store = await _pumpApp(tester);
    await tester.tap(find.text('Subscriptions').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Netflix'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Netflix?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(store.overview.byId('netflix'), isNull);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(store.overview.byId('netflix'), isNotNull);
  });

  testWidgets('empty state after clearing data', (tester) async {
    final store = await _pumpApp(tester);
    await tester.runAsync(store.clearAll);
    await tester.pumpAndSettle();
    expect(find.text('Start your flow'), findsOneWidget);
  });

  testWidgets('error state offers a retry', (tester) async {
    await _pumpApp(tester, repository: _FailingRepository());
    expect(find.text("Couldn't load your data"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('every screen lays out on a small phone', (tester) async {
    await _pumpApp(tester, size: const Size(360, 640));
    for (final tab in ['Subscriptions', 'Upcoming', 'Analytics', 'Home']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Upcoming').last);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Deadlines'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    for (final page in <Widget>[
      const LifeCostScreen(),
      const SettingsScreen(),
      const ExpenseDetailScreen(expenseId: 'car'),
      const ExpenseDetailScreen(expenseId: 'gamepass'),
    ]) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
      await tester.pumpAndSettle();
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byTooltip('Add recurring expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    final details = find.text('Status, cancellation period, contract, notes');
    final sheetList = find
        .descendant(
            of: find.byType(ExpenseFormSheet),
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(details, 200, scrollable: sheetList);
    await tester.drag(sheetList, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(details);
    await tester.pumpAndSettle();
    final notice = find.text('Has a notice period');
    await tester.scrollUntilVisible(notice, 200, scrollable: sheetList);
    await tester.drag(sheetList, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(notice);
    await tester.pumpAndSettle();
    expect(find.textContaining('cancel by'), findsOneWidget);
  });
}
