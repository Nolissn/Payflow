import 'package:intl/intl.dart';

enum AppCurrency {
  eur('EUR', '€', 'Euro'),
  usd('USD', r'$', 'US Dollar'),
  gbp('GBP', '£', 'British Pound'),
  chf('CHF', 'CHF ', 'Swiss Franc');

  const AppCurrency(this.code, this.symbol, this.displayName);
  final String code;
  final String symbol;
  final String displayName;
}

/// Formats amounts consistently across the app: €1,234.56, €1.2k, €1,235.
class MoneyFormat {
  MoneyFormat(this.currency)
      : _full = NumberFormat.currency(
            locale: 'en_US', symbol: currency.symbol, decimalDigits: 2),
        _whole = NumberFormat.currency(
            locale: 'en_US', symbol: currency.symbol, decimalDigits: 0),
        _compact = NumberFormat.compactCurrency(
            locale: 'en_US', symbol: currency.symbol, decimalDigits: 1),
        _plain = NumberFormat('#,##0.00', 'en_US');

  final AppCurrency currency;
  final NumberFormat _full;
  final NumberFormat _whole;
  final NumberFormat _compact;
  final NumberFormat _plain;

  /// €1,234.56
  String call(double amount) => _full.format(_round(amount));

  /// €1,235
  String whole(double amount) => _whole.format(amount.round());

  /// €1.2K for chart labels; small values stay exact.
  String compact(double amount) =>
      amount.abs() < 1000 ? whole(amount) : _compact.format(amount);

  /// 1,234.56 (no symbol) — for hero numbers styled separately.
  String number(double amount) => _plain.format(_round(amount));

  static double _round(double v) => (v * 100).roundToDouble() / 100;
}
