import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';

/// Schedules the follow-up reminders a user sets on a client.
///
/// Everything here is local to the device: no push server, no tokens, no
/// backend. The OS holds the schedule, so reminders still fire when the app is
/// closed.
class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'balance_book_reminders';
  static const _channelName = 'Payment reminders';
  static const _channelDescription =
      'Follow-up reminders you set on a client.';

  bool _ready = false;
  bool _timezoneReady = false;

  /// True once [initialize] has completed. Reminder UI stays hidden until then.
  bool get isReady => _ready;

  Future<void> initialize({
    void Function(String? payload)? onSelect,
  }) async {
    if (_ready) return;
    await _initTimezone();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      // Prompted explicitly later, so the permission dialog appears at a
      // moment the user understands rather than on first launch.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
        onDidReceiveNotificationResponse: (response) =>
            onSelect?.call(response.payload),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.high,
            ),
          );

      _ready = true;
    } catch (e) {
      // Reminders are a convenience; never let them stop the app booting.
      debugPrint('Notification setup failed: $e');
      _ready = false;
    }
  }

  Future<void> _initTimezone() async {
    if (_timezoneReady) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      // Falls back to UTC, which still fires, just without DST correctness.
      debugPrint('Could not resolve local timezone: $e');
    }
    _timezoneReady = true;
  }

  /// Asks for notification permission. Returns whether it was granted.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted = await android?.requestNotificationsPermission();
        return granted ?? false;
      }
      if (Platform.isIOS || Platform.isMacOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final granted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
    return false;
  }

  Future<void> schedule(Reminder reminder) async {
    if (!_ready) return;
    if (!reminder.dueAt.isAfter(DateTime.now())) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    try {
      await _plugin.zonedSchedule(
        id: reminder.notificationId,
        title: reminder.clientName.isEmpty
            ? 'Follow up'
            : 'Follow up with ${reminder.clientName}',
        body: reminder.message,
        scheduledDate: tz.TZDateTime.from(reminder.dueAt, tz.local),
        notificationDetails: details,
        // Inexact allows delivery without the special "alarms & reminders"
        // permission on Android 12+; a few minutes' drift is fine for a
        // follow-up nudge.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: reminder.clientId,
      );
    } catch (e) {
      debugPrint('Could not schedule reminder: $e');
    }
  }

  Future<void> cancel(Reminder reminder) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: reminder.notificationId);
    } catch (e) {
      debugPrint('Could not cancel reminder: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Could not cancel reminders: $e');
    }
  }
}
