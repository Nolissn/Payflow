import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/core/formatting/money_format.dart';
import 'package:payflow/data/backup/backup_service.dart';
import 'package:payflow/data/local/json_file.dart';
import 'package:payflow/data/local/settings_file.dart';
import 'package:payflow/data/repositories/file_expense_repository.dart';
import 'package:payflow/domain/models/billing_cycle.dart';
import 'package:payflow/domain/models/category.dart';
import 'package:payflow/domain/models/recurring_expense.dart';
import 'package:payflow/state/expense_store.dart';
import 'package:payflow/state/settings_store.dart';

RecurringExpense _expense(String id, {List<String> domains = const []}) =>
    RecurringExpense(
      id: id,
      name: 'Item $id',
      amount: 12,
      categoryId: domains.isEmpty ? 'software' : DefaultCategories.domain.id,
      cycle: BillingCycle.yearly,
      nextPaymentDate: DateTime(2026, 11, 1),
      domains: domains,
    );

void main() {
  late Directory temp;
  late DateTime now;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('payflow_test');
    now = DateTime(2026, 9, 22, 10, 30);
  });
  tearDown(() => temp.delete(recursive: true));

  Future<(ExpenseStore, SettingsStore, BackupService)> setUpApp() async {
    final settings = SettingsStore();
    final store = ExpenseStore(
      repository: FileExpenseRepository(
        JsonFile(File('${temp.path}/data/expenses.json')),
      ),
      settings: settings,
    );
    await store.load();
    final backups = BackupService(
      expenses: store,
      settings: settings,
      locationFile: JsonFile(File('${temp.path}/data/backup_location.json')),
      defaultDirectory: () async => Directory('${temp.path}/Payflow'),
      clock: () => now,
    );
    return (store, settings, backups);
  }

  group('local storage', () {
    test('expenses survive an app restart', () async {
      final (store, _, _) = await setUpApp();
      await store.save(_expense('a', domains: ['alpha.com']));
      await store.save(_expense('b'));
      await store.delete('b');

      final (restarted, _, _) = await setUpApp();
      expect(restarted.expenses.map((e) => e.id), ['a']);
      expect(restarted.expenses.single.domains, ['alpha.com']);
    });

    test('a damaged data file shows an error instead of wiping data', () async {
      final file = File('${temp.path}/data/expenses.json');
      await file.create(recursive: true);
      await file.writeAsString('{not json');
      final (store, _, _) = await setUpApp();
      expect(store.status, LoadStatus.error);
      expect(await file.readAsString(), '{not json');
    });

    test('settings are saved on change and loaded on start', () async {
      final file = JsonFile(File('${temp.path}/data/settings.json'));
      final first = SettingsStore();
      await SettingsFile(file).bind(first);
      first
        ..currency = AppCurrency.usd
        ..themeMode = ThemeMode.dark;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final second = SettingsStore();
      await SettingsFile(file).bind(second);
      expect(second.currency, AppCurrency.usd);
      expect(second.themeMode, ThemeMode.dark);
    });
  });

  group('BackupService', () {
    test('writes a readable JSON backup with a timestamped name', () async {
      final (store, _, backups) = await setUpApp();
      await store.save(_expense('a', domains: ['alpha.com', 'beta.dev']));
      final backup = await backups.create();

      expect(backup.name, 'backup_22.09.2026_10-30-00.json');
      final json = jsonDecode(await backup.file.readAsString()) as Map;
      expect(json['app'], 'payflow');
      expect(json['meta'], {'expenseCount': 1, 'domainCount': 2});
      expect((json['expenses'] as List).single['domains'], [
        'alpha.com',
        'beta.dev',
      ]);
      expect(json['settings'], isA<Map>());
    });

    test('two backups in the same second get distinct names', () async {
      final (_, _, backups) = await setUpApp();
      final a = await backups.create();
      final b = await backups.create();
      expect(a.name, isNot(b.name));
      expect(await backups.list(), hasLength(2));
    });

    test('auto-backup skips when nothing changed', () async {
      final (store, _, backups) = await setUpApp();
      await store.save(_expense('a'));
      await backups.autoBackup();
      now = now.add(const Duration(minutes: 1));
      await backups.autoBackup();
      expect(await backups.list(), hasLength(1));

      await store.save(_expense('b'));
      now = now.add(const Duration(minutes: 1));
      await backups.autoBackup();
      expect(await backups.list(), hasLength(2));
    });

    test(
      'restore replaces data and settings and keeps a safety backup',
      () async {
        final (store, settings, backups) = await setUpApp();
        await store.save(_expense('old'));
        settings.currency = AppCurrency.gbp;
        final saved = await backups.create();

        await store.replaceAll([_expense('new1'), _expense('new2')]);
        settings.currency = AppCurrency.chf;
        now = now.add(const Duration(minutes: 5));

        final result = await backups.restore(saved);
        expect(result.expenses, 1);
        expect(store.expenses.map((e) => e.id), ['old']);
        expect(settings.currency, AppCurrency.gbp);
        expect(result.safetyBackup, isNotNull);

        // The safety backup brings back what was there before the restore.
        await backups.restore(result.safetyBackup!);
        expect(store.expenses.map((e) => e.id), ['new1', 'new2']);

        // And it's persisted, not just in memory.
        final (restarted, _, _) = await setUpApp();
        expect(restarted.expenses.map((e) => e.id), ['new1', 'new2']);
      },
    );

    test(
      'rejects files that are not Payflow backups without changing data',
      () async {
        final (store, _, backups) = await setUpApp();
        await store.save(_expense('keep'));
        final dir = await backups.directory();
        final foreign = File('${dir.path}/other.json')
          ..writeAsStringSync('{"prefs": {}}');
        final broken = File('${dir.path}/broken.json')
          ..writeAsStringSync('{"app":"payflow","expenses":[{"id":1}]}');

        for (final f in [foreign, broken]) {
          await expectLater(
            backups.restore(BackupFile(f, DateTime.now(), 0)),
            throwsA(isA<BackupException>()),
          );
        }
        expect(store.expenses.map((e) => e.id), ['keep']);
      },
    );

    test('only restores from the backup folder', () async {
      final (_, _, backups) = await setUpApp();
      final outside = File('${temp.path}/elsewhere.json')
        ..writeAsStringSync('{"app":"payflow","expenses":[]}');
      await expectLater(
        backups.restore(BackupFile(outside, DateTime.now(), 0)),
        throwsA(isA<BackupException>()),
      );
    });

    test('keeps only the newest backups', () async {
      final (_, _, backups) = await setUpApp();
      final dir = await backups.directory();
      for (var i = 0; i < BackupService.maxBackupFiles; i++) {
        File('${dir.path}/old_$i.json')
          ..writeAsStringSync('{}')
          ..setLastModifiedSync(DateTime(2025, 1, 1).add(Duration(days: i)));
      }
      final newest = await backups.create();
      final files = await backups.list();
      expect(files, hasLength(BackupService.maxBackupFiles));
      expect(files.first.name, newest.name);
      expect(files.any((f) => f.name == 'old_0.json'), isFalse);
    });
  });

  group('backup location', () {
    test('a picked folder is used and remembered across restarts', () async {
      final (_, _, backups) = await setUpApp();
      final picked = '${temp.path}/Documents/MyBackups';
      await backups.changeDirectory(picked);
      final backup = await backups.create();
      expect(backup.file.parent.path, picked);

      final (_, _, restarted) = await setUpApp();
      expect(await restarted.customPath(), picked);
      expect((await restarted.directory()).path, picked);
    });

    test('existing backups can be moved to the new folder', () async {
      final (_, _, backups) = await setUpApp();
      final first = await backups.create();
      now = now.add(const Duration(minutes: 1));
      await backups.create();

      final picked = '${temp.path}/Sync';
      final moved = await backups.changeDirectory(picked, moveExisting: true);
      expect(moved, 2);
      final files = await backups.list();
      expect(files.map((f) => f.file.parent.path).toSet(), {picked});
      expect(files.last.name, first.name);
      expect(await Directory('${temp.path}/Payflow').list().isEmpty, isTrue);
    });

    test('without moving, old backups stay where they were', () async {
      final (_, _, backups) = await setUpApp();
      await backups.create();
      await backups.changeDirectory('${temp.path}/Sync');
      expect(await backups.list(), isEmpty);
      expect(await Directory('${temp.path}/Payflow').list().length, 1);
    });

    test('reset goes back to the default folder', () async {
      final (_, _, backups) = await setUpApp();
      await backups.changeDirectory('${temp.path}/Sync');
      await backups.changeDirectory(null);
      expect(await backups.customPath(), isNull);
      expect((await backups.directory()).path, '${temp.path}/Payflow');

      final (_, _, restarted) = await setUpApp();
      expect(await restarted.customPath(), isNull);
    });

    test('a deleted folder is reported, not silently replaced', () async {
      final (store, _, backups) = await setUpApp();
      await store.save(_expense('a'));
      final picked = Directory('${temp.path}/Gone');
      await backups.changeDirectory(picked.path);
      await picked.delete(recursive: true);

      await expectLater(
        backups.create(),
        throwsA(isA<BackupLocationMissing>()),
      );
      await backups.autoBackup(); // quietly does nothing
      expect(await picked.exists(), isFalse);
      expect(await Directory('${temp.path}/Payflow').exists(), isFalse);
    });

    test('an unwritable folder is rejected and the old one kept', () async {
      final (_, _, backups) = await setUpApp();
      final blocker = File('${temp.path}/not_a_folder')..writeAsStringSync('');
      await expectLater(
        backups.changeDirectory(blocker.path),
        throwsA(isA<BackupException>()),
      );
      expect(await backups.customPath(), isNull);
    });

    test('picked folders get a custom_payflow_app subfolder', () {
      expect(
        BackupService.backupFolderIn('/storage/emulated/0/Documents'),
        '/storage/emulated/0/Documents/custom_payflow_app',
      );
      expect(
        BackupService.backupFolderIn('/storage/emulated/0/Documents/'),
        '/storage/emulated/0/Documents/custom_payflow_app',
      );
      // Picking the subfolder itself doesn't nest it again.
      expect(
        BackupService.backupFolderIn(
          '/storage/emulated/0/Documents/custom_payflow_app',
        ),
        '/storage/emulated/0/Documents/custom_payflow_app',
      );
    });

    test('backups land in the subfolder of the picked folder', () async {
      final (_, _, backups) = await setUpApp();
      final picked = Directory('${temp.path}/Documents')..createSync();
      await backups.changeDirectory(BackupService.backupFolderIn(picked.path));
      final backup = await backups.create();
      expect(
        backup.file.parent.path,
        '${picked.path}/${BackupService.pickedSubfolderName}',
      );
      expect(
        picked.listSync().map(
          (e) => e.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
        ),
        [BackupService.pickedSubfolderName],
      );
    });

    test('a deleted custom_payflow_app folder is recreated', () async {
      final (_, _, backups) = await setUpApp();
      final picked = Directory('${temp.path}/Documents')..createSync();
      final target = BackupService.backupFolderIn(picked.path);
      await backups.changeDirectory(target);
      await Directory(target).delete(recursive: true);

      final (_, _, restarted) = await setUpApp();
      final backup = await restarted.create();
      expect(backup.file.parent.path, target);
    });

    test('if the picked folder itself is gone, it is reported', () async {
      final (_, _, backups) = await setUpApp();
      final picked = Directory('${temp.path}/SdCard')..createSync();
      await backups.changeDirectory(BackupService.backupFolderIn(picked.path));
      await picked.delete(recursive: true);

      final (_, _, restarted) = await setUpApp();
      await expectLater(
        restarted.create(),
        throwsA(isA<BackupLocationMissing>()),
      );
      expect(await picked.exists(), isFalse);
    });
  });
}
