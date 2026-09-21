import 'package:flutter/material.dart';

import '../../core/formatting/date_format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand.dart';
import '../../domain/models/billing_cycle.dart';
import '../../domain/services/cost_calculator.dart';
import '../../domain/services/finance_overview.dart';
import '../../shared/widgets/category_visuals.dart';
import '../../shared/widgets/charts/bars.dart';
import '../../shared/widgets/charts/donut_chart.dart';
import '../../shared/widgets/expense_tiles.dart';
import '../../shared/widgets/insight_card.dart';
import '../../shared/widgets/surfaces.dart';
import '../../state/app_scope.dart';
import '../life_cost/life_cost_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  CostPeriod _period = CostPeriod.month;
  int? _selectedCategory;
  int? _selectedMonth;

  double _inPeriod(double yearly) => yearly / _period.perYear;
  String get _per => _period == CostPeriod.month ? '/ mo' : '/ yr';

  @override
  Widget build(BuildContext context) {
    final overview = context.store.overview;
    if (overview.billed.isEmpty) {
      return const SafeArea(
        child: Center(
          child: EmptyState(
            icon: Icons.donut_large_rounded,
            title: 'No data to analyze yet',
            message: 'Once you add recurring expenses, charts and insights '
                'appear here.',
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Analytics', style: context.text.headlineMedium),
                  ),
                  SegmentedButton<CostPeriod>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: CostPeriod.month, label: Text('Month')),
                      ButtonSegment(value: CostPeriod.year, label: Text('Year')),
                    ],
                    selected: {_period},
                    onSelectionChanged: (s) => setState(() => _period = s.first),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 110),
          sliver: SliverList.list(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _LifeCostTeaser(overview: overview),
            ),
            _categorySection(context, overview),
            _projectionSection(context, overview),
            _frequencySection(context, overview),
            _providerSection(context, overview),
            _largestSection(context, overview),
            _countSection(context, overview),
            if (overview.insights.isNotEmpty) ...[
              const SectionHeader(
                title: 'Savings insights',
                subtitle: 'Areas worth reviewing — the decision is yours',
              ),
              for (final i in overview.insights)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: InsightCard(insight: i),
                ),
            ],
          ]),
        ),
      ],
    );
  }

  Widget _categorySection(BuildContext context, FinanceOverview o) {
    final totals = o.byCategory;
    final selected = _selectedCategory == null || _selectedCategory! >= totals.length
        ? null
        : totals[_selectedCategory!];
    final money = context.money;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Expenses by category',
          subtitle: 'Tap a slice or row to focus it',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SurfaceCard(
            padding: const EdgeInsets.fromLTRB(12, 22, 12, 12),
            child: Column(
              children: [
                DonutChart(
                  size: 200,
                  thickness: 24,
                  selectedIndex: _selectedCategory,
                  onSelected: (i) => setState(() => _selectedCategory = i),
                  semanticsLabel: 'Expenses by category chart',
                  segments: [
                    for (final t in totals)
                      ChartSegment(
                        value: t.yearly,
                        color: CategoryVisuals.color(context, t.category),
                        label: t.category.name,
                      ),
                  ],
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selected?.category.name ?? 'Total',
                        style: context.text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      FittedBox(
                        child: Text(
                          money(_inPeriod(selected?.yearly ?? o.summary.yearly)),
                          style: context.text.titleLarge!.figures
                              .copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        selected == null
                            ? _per
                            : '${(selected.share * 100).toStringAsFixed(1)}%',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                for (final (i, t) in totals.indexed)
                  LegendRow(
                    color: CategoryVisuals.color(context, t.category),
                    label: t.category.name,
                    value: money(_inPeriod(t.yearly)),
                    trailing: '${(t.share * 100).round()}%',
                    selected: _selectedCategory == i,
                    onTap: () => setState(() =>
                        _selectedCategory = _selectedCategory == i ? null : i),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _projectionSection(BuildContext context, FinanceOverview o) {
    final months = o.projection;
    final average = o.summary.monthly;
    final sel = _selectedMonth ?? 0;
    final month = months[sel];
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Cash-out, next 12 months',
          subtitle: 'What is actually charged each month vs. your average',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sel == 0
                                ? '${Dates.month(month.month)} (from today)'
                                : Dates.monthYear(month.month),
                            style: context.text.bodySmall,
                          ),
                          AmountText(context.money(month.total),
                              style: context.text.headlineMedium!),
                        ],
                      ),
                    ),
                    Text(
                      '${month.payments.length} payments',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ColumnChart(
                  data: [
                    for (final m in months)
                      ColumnDatum(
                        label: Dates.monthShort(m.month).substring(0, 1),
                        value: m.total,
                        highlight: m.payments.any((p) => o.isLarge(p.amount)),
                      ),
                  ],
                  reference: average,
                  referenceLabel: 'avg ${context.money.whole(average)}',
                  selectedIndex: _selectedMonth,
                  onSelected: (i) => setState(
                      () => _selectedMonth = _selectedMonth == i ? null : i),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Dot(color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text('Regular', style: context.text.bodySmall),
                    const SizedBox(width: 16),
                    _Dot(color: c.accent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('Contains a large payment',
                          style: context.text.bodySmall),
                    ),
                  ],
                ),
                if (month.payments.any((p) => o.isLarge(p.amount))) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Large: ${month.payments.where((p) => o.isLarge(p.amount)).map((p) => '${p.expense.name} ${context.money(p.amount)}').join(', ')}',
                    style: context.text.labelMedium!.copyWith(color: c.onAccentSoft),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _frequencySection(BuildContext context, FinanceOverview o) {
    final mix = o.byFrequency;
    final colors = {
      BillingFrequency.weekly: context.colors.warning,
      BillingFrequency.monthly: Theme.of(context).colorScheme.primary,
      BillingFrequency.quarterly: const Color(0xFF5B6CF0),
      BillingFrequency.yearly: context.colors.accent,
      BillingFrequency.custom: const Color(0xFF9A8C6A),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Monthly vs. yearly billing',
          subtitle: 'How your costs are billed, normalized to the same period',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SurfaceCard(
            padding: const EdgeInsets.fromLTRB(18, 20, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 10),
                  child: StackedBar(
                    height: 14,
                    segments: [
                      for (final f in mix)
                        ChartSegment(value: f.yearly, color: colors[f.frequency]!),
                    ],
                  ),
                ),
                for (final f in mix)
                  LegendRow(
                    color: colors[f.frequency]!,
                    label: '${f.frequency.label} · ${f.count}',
                    value: context.money(_inPeriod(f.yearly)),
                    trailing: '${(f.share * 100).round()}%',
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _providerSection(BuildContext context, FinanceOverview o) {
    final providers = o.byProvider.take(8).toList();
    final max = providers.isEmpty ? 1.0 : providers.first.yearly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Expenses by provider',
          subtitle: 'Top ${providers.length} of ${o.byProvider.length}',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SurfaceCard(
            child: Column(
              children: [
                for (final p in providers)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(p.name,
                                  style: context.text.titleSmall,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text(
                              '${context.money(_inPeriod(p.yearly))} $_per',
                              style: context.text.labelLarge!.figures,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ShareBar(
                          fraction: p.yearly / max,
                          color: CategoryVisuals.color(
                              context, o.categoryOf(p.categoryId)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _largestSection(BuildContext context, FinanceOverview o) {
    final top = o.largest.take(5).toList();
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Largest recurring expenses',
          subtitle: 'Ranked by yearly cost',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final (i, e) in top.indexed)
                  InkWell(
                    onTap: () => openExpense(context, e),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 26,
                            child: Text('${i + 1}',
                                style: context.text.titleMedium!.figures
                                    .copyWith(color: c.textMuted)),
                          ),
                          ExpenseAvatar(
                              expense: e,
                              category: o.categoryOf(e.categoryId),
                              size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.name,
                                    style: context.text.titleSmall,
                                    overflow: TextOverflow.ellipsis),
                                Text(priceLabel(context, e),
                                    style: context.text.bodySmall),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                context.money(CostCalculator.inPeriod(e, _period)),
                                style: context.text.titleSmall!.figures,
                              ),
                              Text(_per, style: context.text.bodySmall),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _countSection(BuildContext context, FinanceOverview o) {
    final totals = [...o.byCategory]..sort((a, b) => b.count.compareTo(a.count));
    final maxCount = totals.isEmpty ? 1 : totals.first.count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Subscriptions per category'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SurfaceCard(
            child: Column(
              children: [
                for (final t in totals)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CategoryIcon(category: t.category, size: 28),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 110,
                          child: Text(t.category.name,
                              style: context.text.bodyMedium!
                                  .copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          child: ShareBar(
                            fraction: t.count / maxCount,
                            color: CategoryVisuals.color(context, t.category),
                            height: 8,
                          ),
                        ),
                        SizedBox(
                          width: 28,
                          child: Text('${t.count}',
                              textAlign: TextAlign.right,
                              style: context.text.titleSmall!.figures),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _LifeCostTeaser extends StatelessWidget {
  const _LifeCostTeaser({required this.overview});
  final FinanceOverview overview;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SurfaceCard(
      color: c.heroBackground,
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const LifeCostScreen())),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Overline('What does my life cost?', color: c.heroMuted),
                const SizedBox(height: 6),
                Text(
                  '${context.money(overview.summary.daily)} every day',
                  style: context.text.titleLarge!.figures
                      .copyWith(color: c.heroForeground),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.heroForeground.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Brand.radiusM),
            ),
            child: Icon(Icons.arrow_forward_rounded, color: c.heroForeground),
          ),
        ],
      ),
    );
  }
}
