// Renders every main screen to PNG for visual review.
//
//   flutter test tool/screenshots_test.dart
//
// Output: build/screenshots/*.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/app.dart';
import '../test/fixtures/demo_expenses.dart';
import 'package:payflow/data/repositories/in_memory_expense_repository.dart';
import 'package:payflow/features/expense_detail/expense_detail_screen.dart';
import 'package:payflow/features/expense_form/expense_form_sheet.dart';
import 'package:payflow/features/life_cost/life_cost_screen.dart';
import 'package:payflow/state/expense_store.dart';
import 'package:payflow/state/settings_store.dart';

Future<void> _loadFonts() async {
  final manrope = FontLoader('Manrope');
  for (final w in [400, 500, 600, 700, 800]) {
    manrope.addFont(File('assets/fonts/Manrope-$w.ttf')
        .readAsBytes()
        .then((b) => ByteData.view(b.buffer)));
  }
  await manrope.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final icons = FontLoader('MaterialIcons')
    ..addFont(File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
        .readAsBytes()
        .then((b) => ByteData.view(b.buffer)));
  await icons.load();
}

final _boundary = GlobalKey();

Future<void> _shot(WidgetTester tester, String name) async {
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
  await tester.runAsync(() async {
    final render =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('build/screenshots/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  final today = DateTime(2026, 9, 21, 9);

  for (final (mode, label) in [(ThemeMode.light, 'light'), (ThemeMode.dark, 'dark')]) {
    for (final size in [const Size(390, 844), const Size(360, 640)]) {
      final tag = '${label}_${size.width.toInt()}';
      testWidgets('screens $tag', (tester) async {
        await tester.runAsync(_loadFonts);
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        final settings = SettingsStore()..themeMode = mode;
        final store = ExpenseStore(
          repository: InMemoryExpenseRepository(
              seed: buildDemoExpenses(today), latency: Duration.zero),
          settings: settings,
          clock: () => today,
        );
        await tester.runAsync(store.load);

        await tester.pumpWidget(RepaintBoundary(
          key: _boundary,
          child: PayflowApp(expenses: store, settings: settings),
        ));
        await _shot(tester, '${tag}_1_home');

        // Scroll home to see lower sections.
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -700));
        await _shot(tester, '${tag}_1b_home_scrolled');
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -900));
        await _shot(tester, '${tag}_1c_home_bottom');

        for (final (i, tab) in ['Subscriptions', 'Upcoming', 'Analytics'].indexed) {
          await tester.tap(find.text(tab).last);
          await _shot(tester, '${tag}_${i + 2}_${tab.toLowerCase()}');
        }
        await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -900));
        await _shot(tester, '${tag}_4b_analytics_scrolled');

        await tester.tap(find.text('Upcoming').last);
        await tester.pump();
        await tester.tap(find.textContaining('Deadlines'));
        await _shot(tester, '${tag}_3b_deadlines');

        final ctx = tester.element(find.byType(Scaffold).first);
        Navigator.of(ctx).push(
            MaterialPageRoute<void>(builder: (_) => const LifeCostScreen()));
        await _shot(tester, '${tag}_5_life_cost');
        Navigator.of(ctx).pop();
        await tester.pump(const Duration(seconds: 1));

        showExpenseForm(ctx);
        await _shot(tester, '${tag}_6_add_form');
        Navigator.of(ctx).pop();
        await tester.pump(const Duration(seconds: 1));

        Navigator.of(ctx).push(MaterialPageRoute<void>(
            builder: (_) => const ExpenseDetailScreen(expenseId: 'car')));
        await _shot(tester, '${tag}_7_detail');
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
