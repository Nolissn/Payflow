import '../../domain/models/billing_cycle.dart';
import '../../domain/models/category.dart';

/// Common services offered as one-tap presets in the add form.
class ExpenseTemplate {
  const ExpenseTemplate(this.name, this.amount, this.category, this.cycle);

  final String name;
  final double amount;
  final ExpenseCategory category;
  final BillingCycle cycle;
}

const expenseTemplates = <ExpenseTemplate>[
  ExpenseTemplate('Netflix', 13.99, DefaultCategories.streaming, BillingCycle.monthly),
  ExpenseTemplate('Spotify', 11.99, DefaultCategories.streaming, BillingCycle.monthly),
  ExpenseTemplate('Disney+', 9.99, DefaultCategories.streaming, BillingCycle.monthly),
  ExpenseTemplate('Amazon Prime', 89.90, DefaultCategories.streaming, BillingCycle.yearly),
  ExpenseTemplate('YouTube Premium', 12.99, DefaultCategories.streaming, BillingCycle.monthly),
  ExpenseTemplate('Apple One', 19.95, DefaultCategories.entertainment, BillingCycle.monthly),
  ExpenseTemplate('iCloud+', 2.99, DefaultCategories.cloud, BillingCycle.monthly),
  ExpenseTemplate('Google One', 1.99, DefaultCategories.cloud, BillingCycle.monthly),
  ExpenseTemplate('Namecheap', 12.00, DefaultCategories.domain, BillingCycle.yearly),
  ExpenseTemplate('Microsoft 365', 99.00, DefaultCategories.software, BillingCycle.yearly),
  ExpenseTemplate('Adobe CC', 66.45, DefaultCategories.software, BillingCycle.monthly),
  ExpenseTemplate('Gym', 29.99, DefaultCategories.fitness, BillingCycle.monthly),
  ExpenseTemplate('PlayStation Plus', 71.99, DefaultCategories.gaming, BillingCycle.yearly),
  ExpenseTemplate('Mobile plan', 19.99, DefaultCategories.telecom, BillingCycle.monthly),
  ExpenseTemplate('Insurance', 240.00, DefaultCategories.insurance, BillingCycle.yearly),
];
