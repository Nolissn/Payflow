/// High-level buckets used by the "What does my life cost?" view.
enum CostGroup {
  subscriptions('Subscriptions'),
  insurance('Insurance'),
  software('Software & cloud'),
  fixedCosts('Fixed costs'),
  other('Other');

  const CostGroup(this.label);
  final String label;
}

/// A spending category. Categories are data (not an enum) so users can add
/// their own later; [iconKey] is resolved to an icon by the UI layer.
class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.group,
    this.isSubscription = true,
  });

  final String id;
  final String name;
  final String iconKey;

  /// ARGB colour value (kept framework-agnostic in the domain layer).
  final int colorValue;
  final CostGroup group;

  /// Whether items in this category are typically "subscriptions" (as opposed
  /// to contracts such as insurance or telecom). Used for wording only.
  final bool isSubscription;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
        'colorValue': colorValue,
        'group': group.name,
        'isSubscription': isSubscription,
      };

  factory ExpenseCategory.fromJson(Map<String, Object?> json) => ExpenseCategory(
        id: json['id']! as String,
        name: json['name']! as String,
        iconKey: json['iconKey']! as String,
        colorValue: (json['colorValue']! as num).toInt(),
        group: CostGroup.values.byName(json['group']! as String),
        isSubscription: json['isSubscription'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) => other is ExpenseCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The built-in categories.
abstract final class DefaultCategories {
  static const streaming = ExpenseCategory(
      id: 'streaming', name: 'Streaming', iconKey: 'streaming',
      colorValue: 0xFFE0555A, group: CostGroup.subscriptions);
  static const software = ExpenseCategory(
      id: 'software', name: 'Software', iconKey: 'software',
      colorValue: 0xFF5B6CF0, group: CostGroup.software);
  static const gaming = ExpenseCategory(
      id: 'gaming', name: 'Gaming', iconKey: 'gaming',
      colorValue: 0xFF9A5BE0, group: CostGroup.subscriptions);
  static const fitness = ExpenseCategory(
      id: 'fitness', name: 'Fitness', iconKey: 'fitness',
      colorValue: 0xFF2FA36B, group: CostGroup.subscriptions);
  static const insurance = ExpenseCategory(
      id: 'insurance', name: 'Insurance', iconKey: 'insurance',
      colorValue: 0xFF2C7FB8, group: CostGroup.insurance,
      isSubscription: false);
  static const transportation = ExpenseCategory(
      id: 'transportation', name: 'Transportation', iconKey: 'transportation',
      colorValue: 0xFFE39B2D, group: CostGroup.fixedCosts,
      isSubscription: false);
  static const finance = ExpenseCategory(
      id: 'finance', name: 'Finance', iconKey: 'finance',
      colorValue: 0xFF3E8E83, group: CostGroup.fixedCosts,
      isSubscription: false);
  static const cloud = ExpenseCategory(
      id: 'cloud', name: 'Cloud / Hosting', iconKey: 'cloud',
      colorValue: 0xFF3AA6C9, group: CostGroup.software);
  static const domain = ExpenseCategory(
      id: 'domain', name: 'Domain', iconKey: 'domain',
      colorValue: 0xFFC7763C, group: CostGroup.software);
  static const telecom = ExpenseCategory(
      id: 'telecom', name: 'Telecommunications', iconKey: 'telecom',
      colorValue: 0xFF7C8A3A, group: CostGroup.fixedCosts,
      isSubscription: false);
  static const entertainment = ExpenseCategory(
      id: 'entertainment', name: 'Entertainment', iconKey: 'entertainment',
      colorValue: 0xFFD4679E, group: CostGroup.subscriptions);
  static const other = ExpenseCategory(
      id: 'other', name: 'Other', iconKey: 'other',
      colorValue: 0xFF8C8F91, group: CostGroup.other, isSubscription: false);

  static const all = <ExpenseCategory>[
    streaming,
    software,
    gaming,
    fitness,
    insurance,
    transportation,
    finance,
    cloud,
    domain,
    telecom,
    entertainment,
    other,
  ];
}
