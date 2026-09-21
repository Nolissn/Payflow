import 'package:flutter/material.dart';

import '../../core/formatting/date_format.dart';
import '../../core/theme/brand.dart';
import '../../domain/services/finance_overview.dart';
import '../../shared/widgets/brand_mark.dart';
import '../../shared/widgets/category_visuals.dart';
import '../../shared/widgets/charts/bars.dart';
import '../../shared/widgets/charts/donut_chart.dart';
import '../../shared/widgets/expense_tiles.dart';
import '../../shared/widgets/insight_card.dart';
import '../../shared/widgets/surfaces.dart';
import '../../state/app_scope.dart';
import '../expense_form/expense_form_sheet.dart';
import '../life_cost/life_cost_screen.dart';
import '../settings/settings_screen.dart';
import '../shell/app_shell.dart';
import 'widgets/large_payments_strip.dart';
import 'widgets/monthly_hero.dart';
import 'widgets/stat_grid.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final overview = store.overview;

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(child: _Header(today: overview.today)),
        ),
        if (store.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: EmptyState(
                icon: Icons.water_drop_outlined,
                title: 'Start your flow',
                message:
                    'Add your first subscription or recurring bill. Payflow '
                    'turns it into monthly, yearly and daily costs instantly.',
                actionLabel: 'Add recurring expense',
                onAction: () => showExpenseForm(context),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 110),
            sliver: SliverList.list(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: MonthlyHero(
                  summary: overview.summary,
                  onOpenLifeCost: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const LifeCostScreen()),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: StatGrid(),
              ),
              _UpcomingSection(overview: overview),
              if (overview.largeUpcoming(days: 90).isNotEmpty) ...[
                SectionHeader(
                  title: 'Larger payments ahead',
                  subtitle:
                      '${context.money.whole(overview.largePaymentThreshold)} '
                      'or more · next 90 days',
                ),
                LargePaymentsStrip(payments: overview.largeUpcoming(days: 90)),
              ],
              _CategorySection(overview: overview),
              if (overview.insights.isNotEmpty) ...[
                SectionHeader(
                  title: 'Worth a look',
                  subtitle: 'Observations, not advice',
                  actionLabel: 'More',
                  onAction: () => ShellScope.of(context).select(AppTab.analytics),
                ),
                for (final insight in overview.insights.take(3))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: InsightCard(insight: insight),
                  ),
              ],
            ]),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.today});
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PayflowLogo(height: 26),
                const SizedBox(height: 6),
                Text(Dates.full(today), style: context.text.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({required this.overview});
  final FinanceOverview overview;

  @override
  Widget build(BuildContext context) {
    final next = overview.upcoming(days: 30).take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Coming up',
          subtitle: 'Next charges in chronological order',
          actionLabel: 'See all',
          onAction: () =>
              ShellScope.of(context).select(AppTab.upcoming, subTab: 0),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: next.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Nothing due in the next 30 days.',
                        style: context.text.bodyMedium),
                  )
                : Column(
                    children: [
                      for (final p in next)
                        PaymentTile(payment: p, dense: true),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.overview});
  final FinanceOverview overview;

  @override
  Widget build(BuildContext context) {
    final totals = overview.byCategory;
    if (totals.isEmpty) return const SizedBox.shrink();
    const shown = 5;
    final top = totals.take(shown).toList();
    final rest = totals.skip(shown).fold<double>(0, (s, t) => s + t.yearly);
    final restShare = totals.skip(shown).fold<double>(0, (s, t) => s + t.share);
    final muted = context.colors.textMuted.withValues(alpha: 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Where it goes',
          subtitle: 'Recurring costs by category, per month',
          actionLabel: 'Analytics',
          onAction: () => ShellScope.of(context).select(AppTab.analytics),
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
                      for (final t in top)
                        ChartSegment(
                          value: t.yearly,
                          color: CategoryVisuals.color(context, t.category),
                        ),
                      if (rest > 0) ChartSegment(value: rest, color: muted),
                    ],
                  ),
                ),
                for (final t in top)
                  LegendRow(
                    color: CategoryVisuals.color(context, t.category),
                    label: t.category.name,
                    value: context.money(t.monthly),
                    trailing: '${(t.share * 100).round()}%',
                  ),
                if (rest > 0)
                  LegendRow(
                    color: muted,
                    label: '${totals.length - shown} more categories',
                    value: context.money(rest / 12),
                    trailing: '${(restShare * 100).round()}%',
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
