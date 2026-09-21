# Payflow

**Keep your financial flow under control.**

Payflow is a personal control center for recurring expenses: subscriptions,
contracts, insurance and bills. It answers, within seconds:

- What do I pay regularly?
- What does it cost per month, per year, per day?
- What will be charged next, and which larger payments are coming?
- Which cancellation deadlines should I be aware of?

## Run

```bash
flutter pub get
flutter run
```

The app starts with realistic demo data (dates are relative to today). Use
**Settings → Delete all data** to see the empty state, or **Load demo data**
to restore it.

## Screens

| Tab / screen | Purpose |
| --- | --- |
| **Home** | Monthly / yearly / daily cost, active count, next payment, next 30 days, nearest cancellation deadline, upcoming charges, large payments, category breakdown, insights |
| **Subscriptions** | All recurring expenses; filter by status, search, sort by next payment, price, name or category; swipe to delete (with undo) |
| **Upcoming** | Chronological payments (30 days / 90 days / 12 months, grouped by month, large payments highlighted) and **Deadlines** (latest cancellation dates) |
| **Analytics** | Category donut, 12-month cash-out vs. average, monthly vs. yearly billing mix, providers, largest expenses, count per category, savings insights; month/year toggle |
| **Life cost** | "What does my life cost?" — all commitments as one number, grouped (subscriptions, insurance, software & cloud, fixed costs, other) and projected over time |
| **Detail** | Normalized costs, share of total, next charges, cancellation deadline, details, pause / cancel / delete |
| **Add / edit** (FAB) | Bottom sheet with quick-add templates and a live interval conversion; details (status, notice period, contract dates, URL, note) are tucked away |

Navigation uses four tabs plus a floating "add" button. Settings are reached
from the Home header because they are rarely needed.

## Architecture

```
lib/
  main.dart                 composition root (pick the repository here)
  app.dart                  MaterialApp, themes, scopes
  core/
    theme/                  brand tokens (Brand, PayflowColors) + ThemeData
    formatting/             money and date formatting
    utils/date_math.dart    DST-safe calendar arithmetic
  domain/                   pure Dart, no Flutter imports
    models/                 RecurringExpense, BillingCycle, NoticePeriod,
                            ExpenseCategory, ExpenseStatus, Insight
    services/
      cost_calculator.dart  single source of truth for interval conversion
      payment_schedule.dart occurrences, next payment, cancellation deadlines
      expense_analytics.dart aggregations (category, group, provider, …)
      insights_engine.dart  neutral savings observations
      finance_overview.dart lazily computed snapshot the UI reads from
  data/
    repositories/           ExpenseRepository interface + in-memory impl
    demo/                   demo data
  state/                    ExpenseStore / SettingsStore (ChangeNotifier)
                            exposed through InheritedNotifier scopes
  shared/widgets/           cards, tiles, brand mark, charts (CustomPainter)
  features/<screen>/        one folder per screen
```

- **UI → state → domain → data.** Widgets never compute money values; they
  read `store.overview` (a `FinanceOverview`), which is rebuilt once per data
  or settings change.
- **All interval math lives in `CostCalculator`.** Every conversion goes
  through the yearly amount: €12 monthly → €144 yearly, €120 yearly → €10
  monthly, €30 weekly → €1,564.29 yearly → €130.36 monthly.
- **Schedules are anchored** on `nextPaymentDate` and roll forward
  automatically. Months are clamped (Jan 31 → Feb 28 → Mar 31).
- **Cancellation deadline** = renewal date − notice period (Nov 15, 30 days →
  Oct 16). If this cycle's deadline has passed, the next renewal is used.
- No state-management package: `ChangeNotifier` + `InheritedNotifier` is
  enough here and keeps the dependency list short.

### Adding Firebase / Supabase

Implement `ExpenseRepository` (e.g. `FirestoreExpenseRepository`) using
`RecurringExpense.toJson` / `fromJson`, and pass it in `main.dart`. Nothing
else changes. Categories are data (`ExpenseCategory`), not an enum, so
user-defined categories can come from the same backend.

Room for future features: income, budgets, bank transactions, CSV import and
detection all fit as new repositories plus new services next to the existing
ones; `FinanceOverview` is the place to expose new derived values.

## Brand system

| Token | Value | Use |
| --- | --- | --- |
| Jade (primary) | `#0E6B5A` / dark `#5ED3B4` | actions, selection, app icon |
| Ember (accent) | `#F26B3A` / dark `#FF8A5C` | used sparingly: deadlines, large payments, the coin |
| Paper / Ink | `#F4F3EE` / `#0F1D1A` | warm neutral grounds and text |
| Night | `#090E0D` → `#212D2A` | dark mode surfaces (stepped elevation, no borders) |
| Typeface | Manrope 400–800 (bundled) | tabular figures for all amounts |
| Shapes | radii 10 / 14 / 20 / 28, pill buttons and chips | |

**The mark:** a single stroke rises as a stem and loops into a bowl, forming
a "P" drawn as one continuous flow. The loop is interrupted by an ember coin:
a payment moving through the cycle. It is drawn by `BrandMarkPainter`, the
same code that renders the app icons.

Dark mode is its own palette, not an inversion: surfaces step up in lightness
instead of using borders, category colors are lifted slightly, and the hero
keeps a deep jade tone.

## Tooling

```bash
flutter test                                    # domain + widget tests
flutter test tool/generate_brand_assets_test.dart   # re-render icon PNGs
dart run flutter_launcher_icons                 # install platform icons
flutter test tool/screenshots_test.dart         # screenshots → build/screenshots
```
