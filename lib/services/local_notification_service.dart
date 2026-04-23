import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../utils/logger.dart';
import 'reminder_copy.dart';

class LocalNotificationService {
  static const _log = AppLogger('LocalNotificationService');
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _random = Random();

  // Notification ID ranges
  static const _mealReminderIdBase = 1000;
  static const _moodReminderIdBase = 2000;

  // Android channels
  static const _mealReminderChannel = AndroidNotificationChannel(
    'meal_reminders',
    'Mahlzeiten-Erinnerungen',
    description: 'Erinnerungen zum Mahlzeiten tracken',
    importance: Importance.high,
  );

  static const _moodReminderChannel = AndroidNotificationChannel(
    'mood_reminders',
    'Bauchgefühl-Erinnerungen',
    description: 'Erinnerungen zum Bauchgefühl tracken',
    importance: Importance.high,
  );

  /// Initialize the local notification plugin and timezone data.
  static Future<void> initialize({
    required void Function(String? route) onNotificationTap,
  }) async {
    tz.initializeTimeZones();
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        _log.debug('notification tapped, route=$route');
        if (route != null && route.isNotEmpty) {
          onNotificationTap(route);
        }
      },
    );

    // Create Android notification channels
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _mealReminderChannel.id,
        _mealReminderChannel.name,
        description: _mealReminderChannel.description,
        importance: _mealReminderChannel.importance,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _moodReminderChannel.id,
        _moodReminderChannel.name,
        description: _moodReminderChannel.description,
        importance: _moodReminderChannel.importance,
      ),
    );

    _log.debug('initialized');
  }

  /// Request notification permissions (iOS + Android 13+).
  static Future<bool> requestPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      _log.debug('POST_NOTIFICATIONS granted=$granted');
      final exactAlarm = await androidPlugin.requestExactAlarmsPermission();
      _log.debug('SCHEDULE_EXACT_ALARM granted=$exactAlarm');
      return granted ?? false;
    }

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return false;
  }

  /// Schedule meal reminders. Cancels existing ones first.
  static Future<void> scheduleMealReminders({
    required List<String> mealReminderTimes,
    required String timezone,
  }) async {
    for (var i = 0; i < 100; i++) {
      await _plugin.cancel(id: _mealReminderIdBase + i);
    }

    final location = tz.getLocation(timezone);

    for (var i = 0; i < mealReminderTimes.length && i < 100; i++) {
      final parts = mealReminderTimes[i].split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final body = ReminderCopy.pickMealBody(hour, _random);

      final scheduledDate = _nextInstanceOfTime(hour, minute, location);
      _log.debug(
        'scheduling meal reminder $i: ${mealReminderTimes[i]} → $scheduledDate '
        '(now=${tz.TZDateTime.now(location)})',
      );
      try {
        await _plugin.zonedSchedule(
          id: _mealReminderIdBase + i,
          title: 'Belly Buddy',
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _mealReminderChannel.id,
              _mealReminderChannel.name,
              channelDescription: _mealReminderChannel.description,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: '/meal-tracker',
        );
        _log.debug('meal reminder $i scheduled OK');
      } catch (e, st) {
        _log.error('meal reminder $i FAILED to schedule', e, st);
      }
    }

    _log.debug(
      'scheduled ${mealReminderTimes.length} meal reminders for tz=$timezone',
    );
  }

  /// Schedule mood reminders. Cancels existing ones first.
  static Future<void> scheduleMoodReminders({
    required List<String> moodReminderTimes,
    required String timezone,
  }) async {
    for (var i = 0; i < 100; i++) {
      await _plugin.cancel(id: _moodReminderIdBase + i);
    }

    final location = tz.getLocation(timezone);

    for (var i = 0; i < moodReminderTimes.length && i < 100; i++) {
      final parts = moodReminderTimes[i].split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final scheduledDate = _nextInstanceOfTime(hour, minute, location);
      final body = ReminderCopy.pickMoodBody(hour, _random);
      _log.debug(
        'scheduling mood reminder $i: ${moodReminderTimes[i]} → $scheduledDate '
        '(now=${tz.TZDateTime.now(location)})',
      );
      try {
        await _plugin.zonedSchedule(
          id: _moodReminderIdBase + i,
          title: 'Belly Buddy',
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _moodReminderChannel.id,
              _moodReminderChannel.name,
              channelDescription: _moodReminderChannel.description,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: '/gut-feeling-tracker',
        );
        _log.debug('mood reminder $i scheduled OK');
      } catch (e, st) {
        _log.error('mood reminder $i FAILED to schedule', e, st);
      }
    }

    // Diagnostic: list all pending notifications
    final pending = await _plugin.pendingNotificationRequests();
    _log.debug('pending notifications after sync: ${pending.length}');
    for (final n in pending) {
      _log.debug('  pending: id=${n.id} title=${n.title} body=${n.body}');
    }
  }

  /// Cancel all meal reminders.
  static Future<void> cancelMealReminders() async {
    for (var i = 0; i < 100; i++) {
      await _plugin.cancel(id: _mealReminderIdBase + i);
    }
    _log.debug('cancelled all meal reminders');
  }

  /// Cancel all mood reminders.
  static Future<void> cancelMoodReminders() async {
    for (var i = 0; i < 100; i++) {
      await _plugin.cancel(id: _moodReminderIdBase + i);
    }
    _log.debug('cancelled all mood reminders');
  }

  /// Cancel all notifications.
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
    _log.debug('cancelled all notifications');
  }

  /// Calculate the next instance of a given time in the given timezone.
  static tz.TZDateTime _nextInstanceOfTime(
    int hour,
    int minute,
    tz.Location location,
  ) {
    final now = tz.TZDateTime.now(location);
    var scheduled = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
