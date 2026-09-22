import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatting/date_format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/date_math.dart';
import '../../domain/models/expense_status.dart';
import '../../domain/models/recurring_expense.dart';
import '../../domain/services/cost_calculator.dart';
import '../../domain/services/payment_schedule.dart';
import '../../shared/widgets/category_visuals.dart';
import '../../shared/widgets/surfaces.dart';
import '../../state/app_scope.dart';
import '../expense_form/expense_form_sheet.dart';

/// Asks for confirmation, deletes and offers "Undo". Returns true if deleted.
Future<bool> confirmAndDelete(BuildContext context, RecurringExpense e) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete ${e.name}?'),
      content: const Text(
          'It will be removed from your totals, schedule and analytics.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            minimumSize: const Size(64, 44),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  await deleteWithUndo(context, e);
  return true;
}

Future<void> deleteWithUndo(BuildContext context, RecurringExpense e) async {
  final store = ExpenseScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  HapticFeedback.mediumImpact();
  final removed = await store.delete(e.id);
  if (removed == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('${removed.name} deleted'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => store.save(removed),
      ),
    ));
}

class ExpenseDetailScreen extends StatelessWidget {
  const ExpenseDetailScreen({super.key, required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context) {
    final overview = context.store.overview;
    final expense = overview.byId(expenseId);
    if (expense == null) {
      // Deleted while open.
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: EmptyState(
            icon: Icons.delete_outline_rounded,
            title: 'This expense no longer exists',
            message: 'It may have been deleted.',
          ),
        ),
      );
    }

    final category = overview.categoryOf(expense.categoryId);
    final c = context.colors;
    final money = context.money;
    final next = overview.nextPaymentOf(expense);
    final deadline = overview.deadlineOf(expense);
    final schedule = PaymentSchedule.datesBetween(
      expense,
      overview.today,
      DateMath.addMonths(overview.today, 24),
    ).take(6).toList();
    final billed = expense.status.isBilled;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showExpenseForm(context, existing: expense),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) async {
              final store = ExpenseScope.read(context);
              switch (v) {
                case 'pause':
                  await store.setStatus(expense.id, ExpenseStatus.paused);
                case 'resume':
                  await store.setStatus(expense.id, ExpenseStatus.active);
                case 'cancel':
                  await store.setStatus(expense.id, ExpenseStatus.cancelled);
                case 'delete':
                  final navigator = Navigator.of(context);
                  if (await confirmAndDelete(context, expense)) navigator.pop();
              }
            },
            itemBuilder: (_) => [
              if (expense.status == ExpenseStatus.active ||
                  expense.status == ExpenseStatus.trial)
                const PopupMenuItem(value: 'pause', child: Text('Pause')),
              if (!billed)
                const PopupMenuItem(value: 'resume', child: Text('Mark as active')),
              if (expense.status != ExpenseStatus.cancelled)
                const PopupMenuItem(
                    value: 'cancel', child: Text('Mark as cancelled')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExpenseAvatar(
                    expense: expense, category: category, size: 56, muted: !billed),
                const SizedBox(height: 14),
                Text(expense.name, style: context.text.headlineMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Tag(category.name, icon: CategoryVisuals.icon(category)),
                    Tag(expense.status.label,
                        tone: switch (expense.status) {
                          ExpenseStatus.active => TagTone.primary,
                          ExpenseStatus.trial => TagTone.accent,
                          _ => TagTone.muted,
                        }),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    AmountText(money(expense.amount),
                        style: context.text.displayMedium!),
                    const SizedBox(width: 8),
                    Text('/ ${expense.cycle.perLabel}',
                        style: context.text.titleMedium!
                            .copyWith(color: c.textSecondary)),
                  ],
                ),
              ],
            ),
          ),

          // Normalised costs
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Row(
              children: [
                for (final p in [CostPeriod.week, CostPeriod.month, CostPeriod.year])
                  Expanded(
                    child: Column(
                      children: [
                        Text('Per ${p.unitLabel}', style: context.text.bodySmall),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            money(CostCalculator.inPeriod(expense, p)),
                            style: context.text.titleMedium!.figures,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (billed && overview.summary.yearly > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(
                '${(CostCalculator.yearly(expense) / overview.summary.yearly * 100).toStringAsFixed(1)}% '
                'of your recurring costs · ${money(CostCalculator.daily(expense))} per day',
                style: context.text.bodySmall,
              ),
            ),

          // Deadline
          if (deadline != null) ...[
            const SizedBox(height: 16),
            _DeadlineCard(deadline: deadline, today: overview.today),
          ],

          // Schedule
          if (billed && schedule.isNotEmpty) ...[
            const SectionHeader(
                title: 'Upcoming charges',
                padding: EdgeInsets.fromLTRB(4, 24, 4, 10)),
            SurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final (i, d) in schedule.indexed)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        i == 0 ? Icons.radio_button_checked_rounded : Icons.circle_outlined,
                        size: 18,
                        color: i == 0
                            ? Theme.of(context).colorScheme.primary
                            : c.textMuted,
                      ),
                      title: Text(Dates.weekday(d) +
                          (d.year != overview.today.year ? ' ${d.year}' : '')),
                      subtitle: Text(Dates.relative(d, overview.today)),
                      trailing: Text(money(expense.amount),
                          style: context.text.titleSmall!.figures),
                    ),
                ],
              ),
            ),
          ] else if (!billed) ...[
            const SizedBox(height: 16),
            SurfaceCard(
              child: Row(
                children: [
                  Icon(Icons.pause_circle_outline_rounded, color: c.textMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${expense.status.label} — not included in your totals '
                      'or upcoming payments.',
                      style: context.text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Domains
          if (expense.domains.isNotEmpty) ...[
            SectionHeader(
                title: expense.domains.length == 1
                    ? 'Domain'
                    : '${expense.domains.length} domains',
                padding: const EdgeInsets.fromLTRB(4, 24, 4, 10)),
            SurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final d in expense.domains)
                    ListTile(
                      leading: Icon(Icons.language_rounded,
                          size: 20, color: c.textMuted),
                      title: Text(d),
                      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                      onTap: () => launchUrl(Uri.https(d),
                          mode: LaunchMode.externalApplication),
                    ),
                ],
              ),
            ),
            if (expense.domains.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                child: Text(
                  '≈ ${money(CostCalculator.yearly(expense) / expense.domains.length)} '
                  'per domain per year',
                  style: context.text.bodySmall,
                ),
              ),
          ],

          // Details
          const SectionHeader(
              title: 'Details', padding: EdgeInsets.fromLTRB(4, 24, 4, 10)),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                _InfoRow('Payment interval', expense.cycle.label),
                if (next != null)
                  _InfoRow('Next payment', Dates.withYear(next)),
                _InfoRow('Cancellation period',
                    expense.noticePeriod?.label ?? 'None'),
                if (expense.startDate != null)
                  _InfoRow('Started', Dates.withYear(expense.startDate!)),
                if (expense.endDate != null)
                  _InfoRow('Ends', Dates.withYear(expense.endDate!)),
                if (expense.url != null)
                  ListTile(
                    title: const Text('Provider website'),
                    subtitle: Text(Uri.tryParse(expense.url!)?.host ?? expense.url!),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => launchUrl(Uri.parse(expense.url!),
                        mode: LaunchMode.externalApplication),
                  ),
              ],
            ),
          ),
          if (expense.note != null) ...[
            const SizedBox(height: 12),
            SurfaceCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sticky_note_2_outlined, size: 20, color: c.textMuted),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(expense.note!, style: context.text.bodyMedium)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => showExpenseForm(context, existing: expense),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit expense'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: context.text.bodyMedium!
                      .copyWith(color: context.colors.textSecondary))),
          Text(value, style: context.text.titleSmall),
        ],
      ),
    );
  }
}

class _DeadlineCard extends StatelessWidget {
  const _DeadlineCard({required this.deadline, required this.today});
  final CancellationDeadline deadline;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final urgent = deadline.daysLeft <= context.settings.deadlineReminderDays;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: urgent ? c.accentSoft : c.primarySoft,
        borderRadius: BorderRadius.circular(Brand.radiusL),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined,
              color: urgent ? c.onAccentSoft : c.onPrimarySoft),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Latest cancellation: ${Dates.long(deadline.deadline)}',
                    style: context.text.titleSmall!.copyWith(
                        color: urgent ? c.onAccentSoft : c.onPrimarySoft)),
                const SizedBox(height: 2),
                Text(
                  'Renews ${Dates.long(deadline.renewalDate)} · '
                  '${deadline.expense.noticePeriod!.label} notice · '
                  '${deadline.daysLeft == 0 ? 'last day today' : '${deadline.daysLeft} days left'}',
                  style: context.text.bodySmall!.copyWith(
                      color: (urgent ? c.onAccentSoft : c.onPrimarySoft)
                          .withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
