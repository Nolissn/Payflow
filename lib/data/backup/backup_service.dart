import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/models/recurring_expense.dart';
import '../../state/expense_store.dart';
import '../../state/settings_store.dart';
import '../local/json_file.dart';

/// Thrown when a backup cannot be written, read or restored.
class BackupException implements Exception {
  const BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The picked backup folder doesn't exist anymore.
class BackupLocationMissing extends BackupException {
  BackupLocationMissing(this.path)
      : super('The backup folder $path can’t be found. It may have been '
            'deleted or be on a removed SD card. Choose a new folder.');

  final String path;
}

/// A backup file in the backup folder.
class BackupFile {
  const BackupFile(this.file, this.modified, this.sizeBytes);

  final File file;
  final DateTime modified;
  final int sizeBytes;

  String get name => file.uri.pathSegments.last;
}

/// What a restore brought back.
class RestoreResult {
  const RestoreResult({required this.expenses, required this.safetyBackup});

  final int expenses;

  /// Backup of the state right before the restore, so it can be undone.
  final BackupFile? safetyBackup;
}

/// Writes the complete app state (expenses + settings) as timestamped JSON
/// files into a `Payflow` folder in the device's shared storage, where they
/// survive uninstalling the app and can be copied off the device.
///
/// Default location — Android: `/storage/emulated/0/Payflow` (needs "All
/// files access"); iOS / desktop: `Documents/Payflow`. The user can pick any
/// other folder; that choice is stored in [locationFile] (on the device only,
/// never inside a backup, since a path from one phone means nothing on
/// another).
class BackupService {
  BackupService({
    required this._expenses,
    required this._settings,
    this.locationFile,
    Future<Directory> Function()? defaultDirectory,
    DateTime Function()? clock,
  })  : _defaultOverride = defaultDirectory,
        _clock = clock ?? DateTime.now;

  static const folderName = 'Payflow';

  /// Backups in a folder the user picked go into this subfolder of it.
  static const pickedSubfolderName = 'custom_payflow_app';
  static const maxBackupFiles = 100;
  static const formatVersion = 1;

  final ExpenseStore _expenses;
  final SettingsStore _settings;
  final JsonFile? locationFile;
  final Future<Directory> Function()? _defaultOverride;
  final DateTime Function() _clock;
  Directory? _directory;
  String? _customPath;
  bool _locationLoaded = false;

  // ---- Folder -------------------------------------------------------------

  /// The folder the user picked, or `null` when the default is used.
  Future<String?> customPath() async {
    await _loadLocation();
    return _customPath;
  }

  Future<void> _loadLocation() async {
    if (_locationLoaded) return;
    _locationLoaded = true;
    try {
      final json = await locationFile?.read();
      if (json is Map && json['path'] is String) _customPath = json['path'];
    } catch (_) {
      // Unreadable → default folder.
    }
  }

  Future<Directory> defaultDirectory() async {
    if (_defaultOverride != null) return _defaultOverride();
    return Directory('${(await _baseDirectory()).path}/$folderName');
  }

  /// The backup folder. With [requestAccess] false, missing storage access
  /// fails instead of showing the permission screen (used by auto-backup).
  ///
  /// A picked folder that no longer exists (deleted, SD card removed) is
  /// reported instead of silently falling back, so no backup goes to a
  /// place the user doesn't expect.
  Future<Directory> directory({bool requestAccess = true}) async {
    if (_directory != null && await _directory!.exists()) return _directory!;
    await _loadLocation();
    if (_defaultOverride == null && Platform.isAndroid) {
      await _ensureAndroidAccess(requestAccess);
    }
    final custom = _customPath;
    if (custom != null) {
      final dir = Directory(custom);
      if (!await dir.exists()) {
        // Our own subfolder was deleted but the picked folder is still
        // there: recreate it. Otherwise report it.
        final ownSubfolder = dir.uri.pathSegments
                .where((s) => s.isNotEmpty)
                .lastOrNull ==
            pickedSubfolderName;
        if (!ownSubfolder || !await dir.parent.exists()) {
          throw BackupLocationMissing(custom);
        }
        await dir.create();
      }
      return _directory = dir;
    }
    final dir = await defaultDirectory();
    await dir.create(recursive: true);
    return _directory = dir;
  }

  /// The folder backups go to when the user picks [picked]:
  /// `<picked>/custom_payflow_app`. Picking that subfolder itself doesn't
  /// nest it a second time.
  static String backupFolderIn(String picked) {
    final trimmed = picked.replaceFirst(RegExp(r'[/\\]+$'), '');
    return Directory(trimmed).uri.pathSegments
                .where((s) => s.isNotEmpty)
                .lastOrNull ==
            pickedSubfolderName
        ? trimmed
        : '$trimmed/$pickedSubfolderName';
  }

  /// Uses [path] for all future backups. With [moveExisting], the backups in
  /// the current folder are moved along. Pass `null` to go back to the
  /// default folder. Returns how many backups were moved.
  Future<int> changeDirectory(String? path, {bool moveExisting = false}) async {
    await _loadLocation();
    if (_defaultOverride == null && Platform.isAndroid) {
      await _ensureAndroidAccess(true);
    }
    final target = path == null ? await defaultDirectory() : Directory(path);
    try {
      await target.create(recursive: true);
      final probe = File('${target.path}/.payflow_write_test');
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
    } catch (_) {
      throw BackupException(
          'Payflow can’t write to ${target.path}. Please choose another folder.');
    }

    // Look at the current folder without creating it.
    final custom = _customPath;
    Directory? current =
        custom == null ? await defaultDirectory() : Directory(custom);
    if (!await current.exists()) current = null; // Nothing to move.

    var moved = 0;
    if (moveExisting &&
        current != null &&
        current.absolute.path != target.absolute.path) {
      for (final backup in await _jsonFiles(current)) {
        var dest = File('${target.path}/${backup.name}');
        if (await dest.exists()) continue;
        try {
          await backup.file.rename(dest.path);
        } on FileSystemException {
          // Different storage volume: copy, keep the timestamp, then delete.
          dest = await backup.file.copy(dest.path);
          await dest.setLastModified(backup.modified);
          await backup.file.delete();
        }
        moved++;
      }
    }

    _customPath = path;
    _directory = null;
    await locationFile?.write(path == null ? null : {'path': path});
    return moved;
  }

  static Future<Directory> _baseDirectory() async {
    if (Platform.isAndroid) {
      // /storage/emulated/0/Android/data/<app>/files → /storage/emulated/0
      final external = await getExternalStorageDirectory();
      if (external != null) {
        final parts = external.path.split('/');
        final androidIndex = parts.indexOf('Android');
        if (androidIndex > 0) {
          return Directory(parts.sublist(0, androidIndex).join('/'));
        }
        return external;
      }
    }
    return getApplicationDocumentsDirectory();
  }

  static Future<void> _ensureAndroidAccess(bool request) async {
    if (await Permission.manageExternalStorage.isGranted ||
        await Permission.storage.isGranted) {
      return;
    }
    if (request) {
      if ((await Permission.manageExternalStorage.request()).isGranted) return;
      if ((await Permission.storage.request()).isGranted) return;
    }
    throw const BackupException(
        'Payflow needs “All files access” to save backups to your storage.');
  }

  // ---- Create -------------------------------------------------------------

  Map<String, Object?> _payload() {
    final expenses = _expenses.expenses;
    return {
      'app': 'payflow',
      'version': formatVersion,
      'exportedAt': _clock().toIso8601String(),
      'meta': {
        'expenseCount': expenses.length,
        'domainCount': expenses.fold<int>(0, (n, e) => n + e.domains.length),
      },
      'expenses': [for (final e in expenses) e.toJson()],
      'settings': _settings.toJson(),
    };
  }

  static String fileNameFor(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'backup_${two(t.day)}.${two(t.month)}.${t.year}_'
        '${two(t.hour)}-${two(t.minute)}-${two(t.second)}.json';
  }

  /// Writes a new backup and returns it.
  Future<BackupFile> create({bool requestAccess = true}) async {
    try {
      final dir = await directory(requestAccess: requestAccess);
      var file = File('${dir.path}/${fileNameFor(_clock())}');
      for (var i = 2; await file.exists(); i++) {
        file = File('${dir.path}/${fileNameFor(_clock()).replaceFirst('.json', '_$i.json')}');
      }
      await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(_payload()),
          flush: true);
      await _trim(dir);
      final stat = await file.stat();
      return BackupFile(file, stat.modified, stat.size);
    } on BackupException {
      rethrow;
    } catch (e) {
      throw BackupException('Backup failed: $e');
    }
  }

  /// Backs up quietly when the app goes to the background. Skipped while the
  /// data hasn't loaded, without storage access, or when nothing changed
  /// since the newest backup (so the folder doesn't fill with duplicates).
  Future<void> autoBackup() async {
    try {
      if (_expenses.status != LoadStatus.ready) return;
      final backups = await list(requestAccess: false);
      if (backups.isNotEmpty &&
          await _sameData(backups.first.file, _payload())) {
        return;
      }
      await create(requestAccess: false);
    } catch (_) {
      // Auto-backup errors are ignored on purpose; manual backups report them.
    }
  }

  static Future<bool> _sameData(File file, Map<String, Object?> current) async {
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
      return jsonEncode(json['expenses']) == jsonEncode(current['expenses']) &&
          jsonEncode(json['settings']) == jsonEncode(current['settings']);
    } catch (_) {
      return false;
    }
  }

  Future<void> _trim(Directory dir) async {
    final files = await _jsonFiles(dir);
    if (files.length <= maxBackupFiles) return;
    for (final old in files.skip(maxBackupFiles)) {
      await old.file.delete();
    }
  }

  // ---- List ---------------------------------------------------------------

  /// All backups, newest first.
  Future<List<BackupFile>> list({bool requestAccess = true}) async =>
      _jsonFiles(await directory(requestAccess: requestAccess));

  static Future<List<BackupFile>> _jsonFiles(Directory dir) async {
    final files = <BackupFile>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
        final stat = await entity.stat();
        files.add(BackupFile(entity, stat.modified, stat.size));
      }
    }
    return files..sort((a, b) => b.modified.compareTo(a.modified));
  }

  // ---- Restore ------------------------------------------------------------

  /// Replaces all expenses and settings with the content of [backup].
  ///
  /// The file is fully validated before anything changes, and the current
  /// state is backed up first so a restore can always be undone.
  Future<RestoreResult> restore(BackupFile backup) async {
    final dir = await directory();
    if (backup.file.parent.absolute.path != dir.absolute.path) {
      throw const BackupException(
          'Backups can only be restored from the backup folder.');
    }

    final List<RecurringExpense> expenses;
    final Map<String, Object?>? settings;
    try {
      final json =
          jsonDecode(await backup.file.readAsString()) as Map<String, Object?>;
      if (json['app'] != 'payflow' || json['expenses'] is! List) {
        throw const FormatException('not a Payflow backup');
      }
      if ((json['version'] as num? ?? 0) > formatVersion) {
        throw const FormatException(
            'made by a newer version of Payflow — update the app first');
      }
      expenses = (json['expenses'] as List)
          .cast<Map<String, Object?>>()
          .map(RecurringExpense.fromJson)
          .toList();
      settings = json['settings'] as Map<String, Object?>?;
    } catch (e) {
      final reason = e is FormatException ? e.message : 'the file is damaged';
      throw BackupException('This backup can’t be restored: $reason.');
    }

    final safety = _expenses.isEmpty ? null : await create();
    await _expenses.replaceAll(expenses);
    if (settings != null) _settings.applyJson(settings);
    return RestoreResult(expenses: expenses.length, safetyBackup: safety);
  }
}
