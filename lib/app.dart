import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';
import 'state/app_scope.dart';
import 'state/expense_store.dart';
import 'state/settings_store.dart';

class PayflowApp extends StatelessWidget {
  const PayflowApp({super.key, required this.expenses, required this.settings});

  final ExpenseStore expenses;
  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      expenses: expenses,
      settings: settings,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          title: 'Payflow',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          locale: const Locale('en', 'US'),
          supportedLocales: const [Locale('en', 'US')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const AppShell(),
        ),
      ),
    );
  }
}
