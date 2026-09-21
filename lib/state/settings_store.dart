import 'package:flutter/material.dart';

import '../core/formatting/money_format.dart';

/// User preferences. Kept in memory for now; persisting them (locally or in
/// a cloud profile) only requires changes inside this class.
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
}
