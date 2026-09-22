import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart' as handler;

/// Every system permission Payflow asks for.
enum AppPermission {
  notifications(
    title: 'Notifications',
    purpose: 'Payment reminders 7 days, 3 days and 1 day before a '
        'subscription is charged.',
    required: true,
  ),
  exactAlarms(
    title: 'Alarms & reminders',
    purpose: 'Delivers payment reminders on time instead of whenever the '
        'system gets around to it.',
    required: false,
  ),
  storage(
    title: 'All files access',
    purpose: 'Saves backups to a folder on your device that survives '
        'uninstalling the app.',
    required: false,
  );

  const AppPermission({
    required this.title,
    required this.purpose,
    required this.required,
  });

  final String title;
  final String purpose;

  /// Core features don't work without it; optional ones only degrade.
  final bool required;

  /// The permissions that exist on the current platform.
  static List<AppPermission> get relevant =>
      Platform.isAndroid ? values : const [notifications];
}

/// Checks and requests [AppPermission]s.
abstract final class AppPermissions {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static IOSFlutterLocalNotificationsPlugin? get _ios =>
      _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  static Future<bool> isGranted(AppPermission permission) async {
    switch (permission) {
      case AppPermission.notifications:
        if (Platform.isAndroid) {
          return await _android?.areNotificationsEnabled() ?? false;
        }
        return (await _ios?.checkPermissions())?.isEnabled ?? false;
      case AppPermission.exactAlarms:
        if (!Platform.isAndroid) return true;
        return await _android?.canScheduleExactNotifications() ?? false;
      case AppPermission.storage:
        if (!Platform.isAndroid) return true;
        return await handler.Permission.manageExternalStorage.isGranted ||
            await handler.Permission.storage.isGranted;
    }
  }

  /// Statuses of all [AppPermission.relevant] permissions.
  static Future<Map<AppPermission, bool>> checkAll() async => {
        for (final p in AppPermission.relevant) p: await isGranted(p),
      };

  /// Shows the system prompt or settings page for [permission] and returns
  /// whether it is granted afterwards.
  static Future<bool> request(AppPermission permission) async {
    switch (permission) {
      case AppPermission.notifications:
        if (Platform.isAndroid) {
          await _android?.requestNotificationsPermission();
        } else {
          await _ios?.requestPermissions(alert: true, badge: true, sound: true);
        }
      case AppPermission.exactAlarms:
        await _android?.requestExactAlarmsPermission();
      case AppPermission.storage:
        if (!(await handler.Permission.manageExternalStorage.request())
            .isGranted) {
          await handler.Permission.storage.request();
        }
    }
    return isGranted(permission);
  }

  /// For permissions the system won't prompt for again (the user denied
  /// them before): opens the app's settings page so they can be enabled
  /// there.
  static Future<void> openSettings(AppPermission permission) async {
    if (permission == AppPermission.notifications) {
      try {
        await _notifications.openAppNotificationSettings();
        return;
      } catch (_) {
        // Fall back to the general app settings page below.
      }
    }
    await handler.openAppSettings();
  }
}
