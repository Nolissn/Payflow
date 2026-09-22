import 'package:flutter/material.dart';

import '../../core/formatting/money_format.dart';
import '../../core/theme/brand.dart';
import '../../shared/widgets/brand_mark.dart';
import '../../shared/widgets/surfaces.dart';
import '../../state/app_scope.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _thresholds = [50.0, 100.0, 200.0, 500.0];
  static const _reminderDays = [3, 7, 14, 30];

  @override
  Widget build(BuildContext context) {
    final settings = context.settings;
    final store = context.store;
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          const SectionHeader(
              title: 'Appearance', padding: EdgeInsets.fromLTRB(4, 12, 4, 10)),
          SurfaceCard(
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto_outlined, size: 18)),
                  ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined, size: 18)),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined, size: 18)),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => settings.themeMode = s.first,
              ),
            ),
          ),
          const SectionHeader(
              title: 'Money', padding: EdgeInsets.fromLTRB(4, 24, 4, 10)),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Currency'),
                  subtitle: Text(settings.currency.displayName),
                  trailing: Text(settings.currency.code,
                      style: Theme.of(context).textTheme.labelLarge),
                  onTap: () => _pickCurrency(context),
                ),
                ListTile(
                  leading: const Icon(Icons.priority_high_rounded),
                  title: const Text('Large payment threshold'),
                  subtitle: const Text('Payments above this are highlighted'),
                  trailing: _ChoiceMenu<double>(
                    value: settings.largePaymentThreshold,
                    values: _thresholds,
                    label: (v) => context.money.whole(v),
                    onChanged: (v) => settings.largePaymentThreshold = v,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Deadline warning'),
                  subtitle: const Text('Flag cancellation deadlines within'),
                  trailing: _ChoiceMenu<int>(
                    value: settings.deadlineReminderDays,
                    values: _reminderDays,
                    label: (v) => '$v days',
                    onChanged: (v) => settings.deadlineReminderDays = v,
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader(
              title: 'Data', padding: EdgeInsets.fromLTRB(4, 24, 4, 10)),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.delete_sweep_outlined,
                      color: Theme.of(context).colorScheme.error),
                  title: Text('Delete all data',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  subtitle: Text('${store.expenses.length} recurring expenses'),
                  onTap: () async {
                    if (await _confirm(context,
                        title: 'Delete all data?',
                        message:
                            'All recurring expenses will be removed. This cannot be undone.',
                        action: 'Delete all',
                        destructive: true)) {
                      await store.clearAll();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Column(
            children: [
              const BrandTile(size: 56),
              const SizedBox(height: 12),
              const PayflowLogo(height: 22),
              const SizedBox(height: 6),
              Text('Keep your financial flow under control.',
                  style: Theme.of(context).textTheme.bodySmall),
              Text('Version 1.0.0 · Data stays on this device',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .copyWith(color: c.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickCurrency(BuildContext context) async {
    final settings = SettingsScope.read(context);
    final picked = await showModalBottomSheet<AppCurrency>(
      context: context,
      builder: (context) => SafeArea(
        child: RadioGroup<AppCurrency>(
          groupValue: settings.currency,
          onChanged: (v) => Navigator.pop(context, v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final cur in AppCurrency.values)
                RadioListTile<AppCurrency>(
                  value: cur,
                  title: Text(cur.displayName),
                  secondary: Text(cur.symbol.trim()),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (picked != null) settings.currency = picked;
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 44),
              backgroundColor: destructive ? scheme.error : null,
              foregroundColor: destructive ? scheme.onError : null,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _ChoiceMenu<T> extends StatelessWidget {
  const _ChoiceMenu({
    required this.value,
    required this.values,
    required this.label,
    required this.onChanged,
  });

  final T value;
  final List<T> values;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final v in values) PopupMenuItem(value: v, child: Text(label(v))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.colors.chartTrack,
          borderRadius: BorderRadius.circular(Brand.radiusS),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label(value), style: Theme.of(context).textTheme.labelLarge),
            const Icon(Icons.expand_more_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}
