import 'package:flutter/material.dart';

import '../core/formatting/money_format.dart';

/// User preferences. Listeners are notified on every change, which is also
/// what persists them (see `SettingsFile`).
class SettingsStore extends ChangeNotifier {
  SettingsStore({
    this._themeMode = ThemeMode.system,
    AppCurrency currency = AppCurrency.eur,
    this._largePaymentThreshold = 100,
    this._deadlineReminderDays = 7,
  })  : _currency = currency,
        _money = MoneyFormat(currency);

  ThemeMode _themeMode;
  AppCurrency _currency;
  MoneyFormat _money;
  double _largePaymentThreshold;
  int _deadlineReminderDays;

  ThemeMode get themeMode => _themeMode;
  AppCurrency get currency => _currency;
  MoneyFormat get money => _money;

  /// Charges at or above this amount are highlighted as "large".
  double get largePaymentThreshold => _largePaymentThreshold;

  /// Deadlines within this many days are flagged as urgent.
  int get deadlineReminderDays => _deadlineReminderDays;

  set themeMode(ThemeMode value) {
    if (value == _themeMode) return;
    _themeMode = value;
    notifyListeners();
  }

  set currency(AppCurrency value) {
    if (value == _currency) return;
    _currency = value;
    _money = MoneyFormat(value);
    notifyListeners();
  }

  set largePaymentThreshold(double value) {
    if (value == _largePaymentThreshold) return;
    _largePaymentThreshold = value;
    notifyListeners();
  }

  set deadlineReminderDays(int value) {
    if (value == _deadlineReminderDays) return;
    _deadlineReminderDays = value;
    notifyListeners();
  }

  Map<String, Object?> toJson() => {
        'themeMode': _themeMode.name,
        'currency': _currency.name,
        'largePaymentThreshold': _largePaymentThreshold,
        'deadlineReminderDays': _deadlineReminderDays,
      };

  /// Applies values from [toJson]. Unknown or missing keys keep their
  /// current value so older files stay readable.
  void applyJson(Map<String, Object?> json) {
    T? pick<T extends Enum>(List<T> values, Object? name) =>
        values.where((v) => v.name == name).firstOrNull;

    _themeMode = pick(ThemeMode.values, json['themeMode']) ?? _themeMode;
    _currency = pick(AppCurrency.values, json['currency']) ?? _currency;
    _money = MoneyFormat(_currency);
    final threshold = json['largePaymentThreshold'];
    if (threshold is num) _largePaymentThreshold = threshold.toDouble();
    final days = json['deadlineReminderDays'];
    if (days is num) _deadlineReminderDays = days.toInt();
    notifyListeners();
  }
}
