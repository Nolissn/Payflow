import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatting/date_format.dart';
import '../../core/theme/brand.dart';
import '../../data/backup/backup_service.dart';
import '../../shared/widgets/surfaces.dart';

/// Create backups and restore one of them. Opened from Settings.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.backups});

  final BackupService backups;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  static const _pageSize = 3;

  bool _busy = true;
  String? _folder;
  bool _isCustomFolder = false;
  bool _folderMissing = false;
  List<BackupFile> _files = const [];
  int _visible = _pageSize;
  String? _status;
  bool _statusError = false;

  BackupService get _service => widget.backups;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    final custom = await _service.customPath();
    try {
      final dir = await _service.directory();
      final files = await _service.list();
      if (!mounted) return;
      setState(() {
        _folder = dir.path;
        _isCustomFolder = custom != null;
        _folderMissing = false;
        _files = files;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _files = const [];
        _isCustomFolder = custom != null;
        _folderMissing = e is BackupLocationMissing;
        if (e is BackupLocationMissing) _folder = e.path;
      });
      _showStatus('$e', error: true);
    }
  }

  Future<void> _pickFolder() async {
    final picked = await FilePicker.getDirectoryPath(
        dialogTitle: 'Choose backup folder');
    if (picked == null) return;
    final target = BackupService.backupFolderIn(picked);
    if (target == _folder && !_folderMissing) return;
    await _switchFolder(target);
  }

  /// Switches to [path] (`null` = default folder), asking whether the
  /// existing backups should move along.
  Future<void> _switchFolder(String? path) async {
    var move = false;
    if (_files.isNotEmpty && !_folderMissing) {
      final n = _files.length;
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Move $n ${n == 1 ? 'backup' : 'backups'}?'),
          content: const Text(
              'Move your existing backups to the new folder, or leave them '
              'where they are? New backups always go to the new folder.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Leave them'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Move'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      move = choice;
    }

    setState(() => _busy = true);
    try {
      final moved = await _service.changeDirectory(path, moveExisting: move);
      HapticFeedback.mediumImpact();
      await _load();
      _showStatus(
        '${path == null ? 'Back to the default folder' : 'Backup folder changed'}.'
        '${moved > 0 ? ' $moved ${moved == 1 ? 'backup' : 'backups'} moved.' : ''}',
      );
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showStatus('$e', error: true);
    }
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final backup = await _service.create();
      HapticFeedback.mediumImpact();
      await _load();
      _showStatus('Backup saved: ${backup.name}');
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showStatus('$e', error: true);
    }
  }

  Future<void> _restore(BackupFile backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          'All current expenses and settings will be replaced with the '
          'backup from ${Dates.withTime(backup.modified)}.\n\n'
          'Your current data is backed up first, so you can go back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final result = await _service.restore(backup);
      HapticFeedback.mediumImpact();
      await _load();
      final n = result.expenses;
      _showStatus(
        'Restored $n recurring ${n == 1 ? 'expense' : 'expenses'}.'
        '${result.safetyBackup == null ? '' : '\nYour previous data was saved as ${result.safetyBackup!.name}.'}',
      );
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showStatus('$e', error: true);
    }
  }

  void _showStatus(String message, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _status = message;
      _statusError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Backups')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _create,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.backup_outlined),
              label: Text(_busy ? 'Please wait…' : 'Back up now'),
            ),
            if (_status != null) ...[
              const SizedBox(height: 12),
              _StatusCard(message: _status!, error: _statusError),
            ],
            const SectionHeader(
                title: 'Saved backups',
                padding: EdgeInsets.fromLTRB(4, 24, 4, 10)),
            if (_files.isEmpty)
              SurfaceCard(
                child: Row(
                  children: [
                    Icon(Icons.inbox_outlined, color: c.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _busy ? 'Loading…' : 'No backups yet',
                        style: context.text.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )
            else
              SurfaceCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final b in _files.take(_visible))
                      ListTile(
                        leading: Icon(Icons.description_outlined,
                            color: Theme.of(context).colorScheme.primary),
                        title: Text(Dates.withTime(b.modified)),
                        subtitle: Text('${b.name} · ${_size(b.sizeBytes)}',
                            overflow: TextOverflow.ellipsis),
                        trailing: TextButton(
                          onPressed: _busy ? null : () => _restore(b),
                          child: const Text('Restore'),
                        ),
                      ),
                  ],
                ),
              ),
            if (_files.length > _visible)
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _visible += _pageSize),
                  icon: const Icon(Icons.expand_more_rounded),
                  label: Text('Show more (${_files.length - _visible} more)'),
                ),
              ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.autorenew_rounded,
              title: 'Automatic backup',
              message: 'Payflow also backs up whenever you leave the app, '
                  'if anything changed. The newest '
                  '${BackupService.maxBackupFiles} backups are kept.',
            ),
            const SectionHeader(
                title: 'Location', padding: EdgeInsets.fromLTRB(4, 24, 4, 10)),
            _InfoCard(
              icon: _folderMissing
                  ? Icons.folder_off_outlined
                  : Icons.folder_outlined,
              title: _folderMissing
                  ? 'Folder not found'
                  : _isCustomFolder
                      ? 'Your folder'
                      : 'Default folder',
              message: _folder ?? (_busy ? 'Loading…' : 'Not available'),
              selectable: true,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickFolder,
                  icon: const Icon(Icons.drive_folder_upload_outlined),
                  label: const Text('Change folder'),
                ),
                if (_isCustomFolder)
                  TextButton(
                    onPressed: _busy ? null : () => _switchFolder(null),
                    child: const Text('Use default folder'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'When you choose a folder, Payflow creates a '
                '“${BackupService.pickedSubfolderName}” folder inside it for '
                'the backups. '
                'Backups stay in this folder even if you uninstall Payflow. '
                'Tip: pick a folder that a sync app (e.g. Nextcloud or '
                'Syncthing) uploads, so your backups are safe even if you '
                'lose your phone. Folders on SD cards may not work on every '
                'device.',
                style: context.text.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _size(int bytes) => bytes < 1024
      ? '$bytes B'
      : '${(bytes / 1024).toStringAsFixed(bytes < 10240 ? 1 : 0)} KB';
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.message, required this.error});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final foreground = error ? scheme.onErrorContainer : c.onPrimarySoft;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : c.primarySoft,
        borderRadius: BorderRadius.circular(Brand.radiusM),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline,
              size: 20, color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: context.text.bodyMedium!.copyWith(color: foreground)),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
    this.selectable = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = context.text.bodySmall;
    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                const SizedBox(height: 2),
                selectable
                    ? SelectableText(message, style: style)
                    : Text(message, style: style),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
