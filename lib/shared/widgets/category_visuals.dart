import 'package:flutter/material.dart';

import '../../core/theme/brand.dart';
import '../../domain/models/category.dart';
import '../../domain/models/recurring_expense.dart';

/// Maps domain categories to icons and theme-aware colours.
abstract final class CategoryVisuals {
  static const _icons = <String, IconData>{
    'streaming': Icons.play_circle_outline_rounded,
    'software': Icons.code_rounded,
    'gaming': Icons.sports_esports_outlined,
    'fitness': Icons.fitness_center_rounded,
    'insurance': Icons.shield_outlined,
    'transportation': Icons.directions_transit_outlined,
    'finance': Icons.account_balance_outlined,
    'cloud': Icons.cloud_outlined,
    'domain': Icons.language_rounded,
    'telecom': Icons.cell_tower_rounded,
    'entertainment': Icons.auto_stories_outlined,
    'other': Icons.category_outlined,
  };

  static IconData icon(ExpenseCategory category) =>
      _icons[category.iconKey] ?? Icons.category_outlined;

  /// Category colours are lifted slightly in dark mode so they keep contrast
  /// on dark surfaces without becoming neon.
  static Color color(BuildContext context, ExpenseCategory category) {
    final base = Color(category.colorValue);
    if (!context.isDark) return base;
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness((hsl.lightness + 0.12).clamp(0, 0.72))
        .withSaturation((hsl.saturation * 0.85).clamp(0, 1))
        .toColor();
  }

  static Color tint(BuildContext context, ExpenseCategory category) =>
      color(context, category).withValues(alpha: context.isDark ? 0.18 : 0.12);
}

/// Rounded-square icon badge for a category.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({super.key, required this.category, this.size = 40});

  final ExpenseCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: CategoryVisuals.tint(context, category),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        CategoryVisuals.icon(category),
        size: size * 0.5,
        color: CategoryVisuals.color(context, category),
      ),
    );
  }
}

/// Provider monogram tinted with the category colour: "N" for Netflix.
class ExpenseAvatar extends StatelessWidget {
  const ExpenseAvatar({
    super.key,
    required this.expense,
    required this.category,
    this.size = 44,
    this.muted = false,
  });

  final RecurringExpense expense;
  final ExpenseCategory category;
  final double size;
  final bool muted;

  String get _initials {
    final words = expense.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    final first = words.first.characters.first.toUpperCase();
    if (words.length == 1) return first;
    final second = words[1].characters.first;
    return RegExp(r'[A-Za-z0-9]').hasMatch(second)
        ? '$first${second.toUpperCase()}'
        : first;
  }

  @override
  Widget build(BuildContext context) {
    final color = muted
        ? context.colors.textMuted
        : CategoryVisuals.color(context, category);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: context.isDark ? 0.2 : 0.13),
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: Text(
          _initials,
          style: TextStyle(
            fontFamily: Brand.fontFamily,
            fontWeight: FontWeight.w800,
            fontSize: size * (_initials.length > 1 ? 0.34 : 0.42),
            letterSpacing: -0.5,
            color: color,
            height: 1,
          ),
        ),
      ),
    );
  }
}
