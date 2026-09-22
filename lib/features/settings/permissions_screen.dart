import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/brand.dart';
import '../../data/permissions/app_permissions.dart';
import '../../shared/widgets/surfaces.dart';

/// Lists every permission Payflow uses, whether it is active, and lets the
/// user grant the missing ones. Opened from Settings.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  static const _icons = {
    AppPermission.notifications: Icons.notifications_outlined,
    AppPermission.exactAlarms: Icons.alarm_outlined,
    AppPermission.storage: Icons.folder_outlined,
  };

  Map<AppPermission, bool>? _granted;

  /// Permissions requested in this session that are still denied. The
  /// system won't show its prompt again for these, so their button opens
  /// the app's settings instead.
  final _asked = <AppPermission>{};
  bool _busy = false;
  String? _result;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Picks up changes made in the system settings.
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final granted = await AppPermissions.checkAll();
    if (!mounted) return;
    setState(() => _granted = granted);
  }

  Future<void> _grant(AppPermission permission) async {
    setState(() => _busy = true);
    if (_asked.contains(permission)) {
      await AppPermissions.openSettings(permission);
    } else if (!await AppPermissions.request(permission)) {
      _asked.add(permission);
    }
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  /// Re-checks every permission and asks for the missing ones.
  Future<void> _checkAll() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    for (final p in AppPermission.relevant) {
      if (await AppPermissions.isGranted(p) || _asked.contains(p)) continue;
      if (!await AppPermissions.request(p)) _asked.add(p);
    }
    final granted = await AppPermissions.checkAll();
    if (!mounted) return;
    final missing = [
      for (final e in granted.entries)
        if (!e.value) e.key.title,
    ];
    HapticFeedback.mediumImpact();
    setState(() {
      _granted = granted;
      _busy = false;
      _result = missing.isEmpty
          ? 'All permissions are granted.'
          : 'Still missing: ${missing.join(', ')}. Tap “Open settings” to '
              'enable ${missing.length == 1 ? 'it' : 'them'} there.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final granted = _granted;
    final missing = granted?.values.where((g) => !g).length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: granted == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, 32 + MediaQuery.paddingOf(context).bottom),
              children: [
                _Summary(total: granted.length, missing: missing),
                const SectionHeader(
                    title: 'What Payflow uses',
                    padding: EdgeInsets.fromLTRB(4, 24, 4, 10)),
                for (final p in AppPermission.relevant) ...[
                  _PermissionCard(
                    permission: p,
                    icon: _icons[p]!,
                    granted: granted[p] ?? false,
                    openSettings: _asked.contains(p),
                    onGrant: _busy ? null : () => _grant(p),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _busy ? null : _checkAll,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.verified_user_outlined),
                  label: const Text('Check permissions'),
                ),
                if (_result case final result?) ...[
                  const SizedBox(height: 12),
                  _ResultCard(message: result, ok: missing == 0),
                ],
              ],
            ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.total, required this.missing});

  final int total;
  final int missing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ok = missing == 0;
    final color = ok ? c.positive : c.warning;
    return SurfaceCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: context.isDark ? 0.2 : 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
                ok ? Icons.verified_outlined : Icons.warning_amber_rounded,
                color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok
                      ? 'All permissions active'
                      : '$missing of $total ${missing == 1 ? 'permission' : 'permissions'} missing',
                  style: context.text.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  ok
                      ? 'Payment reminders and backups work as intended.'
                      : 'Some features may not work until you allow them.',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.permission,
    required this.icon,
    required this.granted,
    required this.openSettings,
    required this.onGrant,
  });

  final AppPermission permission;
  final IconData icon;
  final bool granted;
  final bool openSettings;
  final VoidCallback? onGrant;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: granted ? c.textSecondary : c.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(permission.title, style: context.text.titleSmall),
                        Tag(permission.required ? 'Required' : 'Optional',
                            tone: TagTone.muted),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(permission.purpose, style: context.text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 36),
              granted
                  ? const Tag('Active',
                      tone: TagTone.primary, icon: Icons.check_rounded)
                  : Tag('Not active',
                      tone: permission.required
                          ? TagTone.warning
                          : TagTone.neutral,
                      icon: Icons.close_rounded),
              const Spacer(),
              if (!granted)
                TextButton(
                  onPressed: onGrant,
                  child: Text(openSettings ? 'Open settings' : 'Allow'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.message, required this.ok});

  final String message;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final foreground = ok ? c.onPrimarySoft : c.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok ? c.primarySoft : c.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Brand.radiusM),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.info_outline_rounded,
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
