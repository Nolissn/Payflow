import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/brand.dart';
import '../../domain/models/expense_status.dart';
import '../../domain/models/recurring_expense.dart';
import '../../domain/services/cost_calculator.dart';
import '../../domain/services/finance_overview.dart';
import '../../shared/widgets/category_visuals.dart';
import '../../shared/widgets/expense_tiles.dart';
import '../../shared/widgets/surfaces.dart';
import '../../state/app_scope.dart';
import '../expense_detail/expense_detail_screen.dart';
import '../expense_form/expense_form_sheet.dart';

enum SortOrder {
  nextPayment('Next payment', Icons.event_rounded),
  price('Price', Icons.euro_rounded),
  name('Name', Icons.sort_by_alpha_rounded),
  category('Category', Icons.category_outlined);

  const SortOrder(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum StatusFilter {
  active('Active'),
  paused('Paused'),
  cancelled('Cancelled'),
  all('All');

  const StatusFilter(this.label);
  final String label;

  bool matches(RecurringExpense e) => switch (this) {
        StatusFilter.active => e.status.isBilled,
        StatusFilter.paused => e.status == ExpenseStatus.paused,
        StatusFilter.cancelled => e.status == ExpenseStatus.cancelled,
        StatusFilter.all => true,
      };
}

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  SortOrder _sort = SortOrder.nextPayment;
  StatusFilter _filter = StatusFilter.active;
  String _query = '';

  List<RecurringExpense> _visible(FinanceOverview o) {
    final q = _query.trim().toLowerCase();
    final items = o.all
        .where(_filter.matches)
        .where((e) =>
            q.isEmpty ||
            e.name.toLowerCase().contains(q) ||
            e.domains.any((d) => d.contains(q)))
        .toList();
    int byNext(RecurringExpense a, RecurringExpense b) {
      final da = o.nextPaymentOf(a), db = o.nextPaymentOf(b);
      if (da == null && db == null) return a.name.compareTo(b.name);
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    }

    return switch (_sort) {
      SortOrder.nextPayment => items.sorted(byNext),
      SortOrder.price => items.sorted((a, b) =>
          CostCalculator.monthly(b).compareTo(CostCalculator.monthly(a))),
      SortOrder.name => items.sorted(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      SortOrder.category => items.sorted((a, b) {
          final c = o.categoryOf(a.categoryId).name
              .compareTo(o.categoryOf(b.categoryId).name);
          return c != 0
              ? c
              : CostCalculator.monthly(b).compareTo(CostCalculator.monthly(a));
        }),
    };
  }

  @override
  Widget build(BuildContext context) {
    final overview = context.store.overview;
    final items = _visible(overview);
    final summary = CostCalculator.summarize(items.where((e) => e.status.isBilled));

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Subscriptions',
                        style: context.text.headlineMedium),
                  ),
                  PopupMenuButton<SortOrder>(
                    tooltip: 'Sort',
                    initialValue: _sort,
                    onSelected: (s) => setState(() => _sort = s),
                    itemBuilder: (_) => [
                      for (final s in SortOrder.values)
                        PopupMenuItem(
                          value: s,
                          child: Row(children: [
                            Icon(s.icon, size: 18),
                            const SizedBox(width: 12),
                            Text(s.label),
                          ]),
                        ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Icon(Icons.swap_vert_rounded,
                            size: 18, color: context.colors.textSecondary),
                        const SizedBox(width: 4),
                        Text(_sort.label, style: context.text.labelLarge),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              '${summary.count} billed · ${context.money(summary.monthly)} / month'
              ' · ${context.money(summary.yearly)} / year',
              style: context.text.bodySmall!.figures,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search',
                prefixIcon: Icon(Icons.search_rounded),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              children: [
                for (final f in StatusFilter.values) ...[
                  ChoiceChip(
                    label: Text(
                        '${f.label} ${overview.all.where(f.matches).length}'),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: overview.all.isEmpty
                  ? EmptyState(
                      icon: Icons.layers_outlined,
                      title: 'No recurring expenses yet',
                      message:
                          'Add Netflix, your gym or insurance — it takes seconds.',
                      actionLabel: 'Add recurring expense',
                      onAction: () => showExpenseForm(context),
                    )
                  : EmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'Nothing here',
                      message: _query.isEmpty
                          ? 'No ${_filter.label.toLowerCase()} expenses.'
                          : 'No matches for “$_query”.',
                    ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 110),
            sliver: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final e = items[i];
                final showHeader = _sort == SortOrder.category &&
                    (i == 0 || items[i - 1].categoryId != e.categoryId);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showHeader) _CategoryHeader(overview: overview, items: items, categoryId: e.categoryId),
                    _SwipeToDelete(expense: e, child: ExpenseTile(expense: e)),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.overview,
    required this.items,
    required this.categoryId,
  });

  final FinanceOverview overview;
  final List<RecurringExpense> items;
  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final category = overview.categoryOf(categoryId);
    final group = items.where((e) => e.categoryId == categoryId && e.status.isBilled);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Row(
        children: [
          CategoryIcon(category: category, size: 24),
          const SizedBox(width: 10),
          Expanded(child: Text(category.name, style: context.text.titleSmall)),
          Text('${context.money(CostCalculator.summarize(group).monthly)} / mo',
              style: context.text.bodySmall!.figures),
        ],
      ),
    );
  }
}

class _SwipeToDelete extends StatelessWidget {
  const _SwipeToDelete({required this.expense, required this.child});
  final RecurringExpense expense;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Dismissible(
      key: ValueKey('dismiss-${expense.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: error.withValues(alpha: 0.12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Delete',
                style: context.text.labelLarge!.copyWith(color: error)),
            const SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: error),
          ],
        ),
      ),
      onDismissed: (_) => deleteWithUndo(context, expense),
      child: child,
    );
  }
}
