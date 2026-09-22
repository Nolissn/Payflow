import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/backup/backup_service.dart';
import 'data/local/json_file.dart';
import 'data/local/settings_file.dart';
import 'data/notifications/reminder_notifications.dart';
import 'data/repositories/file_expense_repository.dart';
import 'state/expense_store.dart';
import 'state/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Composition root: swap the repository here to move to Firebase /
  // Supabase. Nothing else in the app depends on the concrete backend.
  final dataDir = await getApplicationSupportDirectory();
  JsonFile file(String name) => JsonFile(File('${dataDir.path}/$name'));

  final settings = SettingsStore();
  await SettingsFile(file('settings.json')).bind(settings);
  final expenses = ExpenseStore(
    repository: FileExpenseRepository(file('expenses.json')),
    settings: settings,
  )..load();
  final backups = BackupService(
    expenses: expenses,
    settings: settings,
    locationFile: file('backup_location.json'),
  );

  // Payment reminders follow every change to the expenses; the store also
  // notifies when the app resumes on a new day.
  ReminderNotifications(expenses: expenses, settings: settings)
      .init()
      .ignore();

  // Like a save on exit: back up whenever the app leaves the foreground.
  AppLifecycleListener(
    onPause: backups.autoBackup,
    onDetach: backups.autoBackup,
  );

  runApp(PayflowApp(expenses: expenses, settings: settings, backups: backups));
}
