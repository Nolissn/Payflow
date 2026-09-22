import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../core/formatting/date_format.dart';
import '../../domain/services/payment_reminders.dart';
import '../../state/expense_store.dart';
import '../../state/settings_store.dart';

/// Keeps the device's scheduled payment reminders in sync with the
/// expenses: whenever an expense or the currency changes (and when the app
/// comes back to the foreground on a new day), all pending reminders are
/// replaced with a freshly planned set.
class ReminderNotifications {
  ReminderNotifications({
    required this._expenses,
    required this._settings,
  });

  final ExpenseStore _expenses;
  final SettingsStore _settings;
  final _plugin = FlutterLocalNotificationsPlugin();

  Timer? _debounce;
  Future<void> _running = Future.value();

  Future<void> init() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    tz_data.initializeTimeZones();
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          // Permission is asked for on the Permissions screen instead of at
          // launch.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
      return;
    }
    _expenses.addListener(_scheduleSync);
    _settings.addListener(_scheduleSync);
    _scheduleSync();
  }

  /// Coalesces bursts of changes (e.g. restoring a backup) into one sync.
  void _scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _running = _running.then((_) => sync()).catchError(
          (Object e) => debugPrint('Scheduling reminders failed: $e'));
    });
  }

  Future<void> sync() async {
    // Don't wipe the reminders while the expenses are still loading.
    if (_expenses.status != LoadStatus.ready) return;
    final reminders = PaymentReminders.plan(_expenses.expenses, DateTime.now());
    final exact = await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.canScheduleExactNotifications() ??
        false;

    await _plugin.cancelAllPendingNotifications();
    for (final (i, reminder) in reminders.indexed) {
      final (title, body) = _text(reminder);
      await _plugin.zonedSchedule(
        id: i,
        // Converting the absolute instant keeps it correct regardless of
        // the device's time zone database.
        scheduledDate: tz.TZDateTime.from(reminder.fireAt, tz.UTC),
        title: title,
        body: body,
        payload: reminder.expense.id,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'payment_reminders',
            'Payment reminders',
            channelDescription: 'Reminders 7 days, 3 days and 1 day before '
                'a subscription is charged',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  (String, String) _text(PaymentReminder r) {
    final amount = _settings.money(r.amount);
    final when = switch (r.daysBefore) {
      1 => 'due tomorrow',
      final d => 'due in $d days',
    };
    final domains = r.expense.domains;
    final name = domains.length == 1
        ? '${r.expense.name} (${domains.first})'
        : r.expense.name;
    return (
      '$name: $amount $when',
      '$amount will be charged on ${Dates.full(r.paymentDate)}.',
    );
  }
}
