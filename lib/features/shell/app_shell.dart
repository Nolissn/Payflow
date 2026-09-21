import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/widgets/surfaces.dart';
import '../../state/app_scope.dart';
import '../../state/expense_store.dart';
import '../analytics/analytics_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../expense_form/expense_form_sheet.dart';
import '../payments/payments_screen.dart';
import '../subscriptions/subscriptions_screen.dart';

enum AppTab {
  home('Home', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  subscriptions('Subscriptions', Icons.layers_outlined, Icons.layers_rounded),
  upcoming('Upcoming', Icons.event_outlined, Icons.event_rounded),
  analytics('Analytics', Icons.donut_large_outlined, Icons.donut_large_rounded);

  const AppTab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Lets any screen switch tabs, e.g. "See all" → Upcoming.
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.select, required super.child});

  final void Function(AppTab tab, {int? subTab}) select;

  static ShellScope of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellScope>()!;

  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

/// Four tabs cover the core loop — overview, list, schedule, analysis.
/// Settings live behind the avatar on Home (rarely needed), and "add" is
/// always one tap away through the floating action button.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  AppTab _tab = AppTab.home;
  final _upcomingTab = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _upcomingTab.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ExpenseScope.read(context).refreshDay();
    }
  }

  void _select(AppTab tab, {int? subTab}) {
    if (tab == AppTab.upcoming && subTab != null) _upcomingTab.value = subTab;
    if (tab == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final ready = store.status == LoadStatus.ready;

    final Widget body = switch (store.status) {
      LoadStatus.loading => const SafeArea(child: LoadingList()),
      LoadStatus.error => ErrorState(
          message: store.error ?? 'Something went wrong.',
          onRetry: store.load,
        ),
      LoadStatus.ready => IndexedStack(
          index: _tab.index,
          children: [
            const DashboardScreen(),
            const SubscriptionsScreen(),
            PaymentsScreen(initialTab: _upcomingTab),
            const AnalyticsScreen(),
          ],
        ),
    };

    return ShellScope(
      select: _select,
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(key: ValueKey(store.status), child: body),
        ),
        floatingActionButton: ready && !store.isEmpty
            ? FloatingActionButton(
                tooltip: 'Add recurring expense',
                onPressed: () => showExpenseForm(context),
                child: const Icon(Icons.add_rounded, size: 28),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab.index,
          onDestinationSelected: (i) => _select(AppTab.values[i]),
          destinations: [
            for (final tab in AppTab.values)
              NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.selectedIcon),
                label: tab.label,
              ),
          ],
        ),
      ),
    );
  }
}
