import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../utils/logger.dart';

class LocalNotificationService {
  static const _log = AppLogger('LocalNotificationService');
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _random = Random();

  // Notification ID ranges
  static const _reminderIdBase = 1000;
  static const _dailySummaryId = 2000;

  // Android channels
  static const _reminderChannel = AndroidNotificationChannel(
    'logging_reminders',
    'Erinnerungen',
    description: 'Tägliche Erinnerungen zum Tracken',
    importance: Importance.high,
  );

  static const _dailySummaryChannel = AndroidNotificationChannel(
    'daily_summary',
    'Tägliche Zusammenfassung',
    description: 'Abendliche Bauchgefühl-Erinnerung',
    importance: Importance.high,
  );

  static const _reminderMessages = [
    'Zeit zum Eintragen! Was hast du gegessen?',
    'Vergiss nicht, deine Mahlzeiten zu tracken!',
    'Wie geht es deinem Bauch? Trag es ein!',
    'Erinnerung: Halte dein Essens-Tagebuch aktuell.',
  ];

  /// Initialize the local notification plugin and timezone data.
  static Future<void> initialize({
    required void Function(String? route) onNotificationTap,
  }) async {
    tz.initializeTimeZones();
    final currentTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTz));

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
      settings,
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
        _reminderChannel.id,
        _reminderChannel.name,
        description: _reminderChannel.description,
        importance: _reminderChannel.importance,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _dailySummaryChannel.id,
        _dailySummaryChannel.name,
        description: _dailySummaryChannel.description,
        importance: _dailySummaryChannel.importance,
      ),
    );

    // Request permission on init so local notifications work immediately
    await requestPermission();

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

  /// Schedule all logging reminders based on user's reminder times.
  /// Cancels existing reminders first.
  static Future<void> scheduleReminders({
    required List<String> reminderTimes,
    required String timezone,
  }) async {
    // Cancel existing reminders
    for (var i = 0; i < 100; i++) {
      await _plugin.cancel(_reminderIdBase + i);
    }

    final location = tz.getLocation(timezone);

    for (var i = 0; i < reminderTimes.length && i < 100; i++) {
      final parts = reminderTimes[i].split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final body = _reminderMessages[_random.nextInt(_reminderMessages.length)];

      await _plugin.zonedSchedule(
        _reminderIdBase + i,
        'Belly Buddy',
        body,
        _nextInstanceOfTime(hour, minute, location),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _reminderChannel.id,
            _reminderChannel.name,
            channelDescription: _reminderChannel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: '/dashboard',
      );
    }

    _log.debug('scheduled ${reminderTimes.length} reminders for tz=$timezone');
  }

  /// Schedule daily summary notification.
  static Future<void> scheduleDailySummary({
    required String dailySummaryTime,
    required String timezone,
  }) async {
    await _plugin.cancel(_dailySummaryId);

    final parts = dailySummaryTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final location = tz.getLocation(timezone);

    await _plugin.zonedSchedule(
      _dailySummaryId,
      'Belly Buddy',
      'Wie war dein Bauchgefühl heute?',
      _nextInstanceOfTime(hour, minute, location),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _dailySummaryChannel.id,
          _dailySummaryChannel.name,
          channelDescription: _dailySummaryChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: '/gut-feeling-tracker',
    );

    _log.debug('scheduled daily summary at $dailySummaryTime tz=$timezone');
  }

  /// Cancel all logging reminders.
  static Future<void> cancelReminders() async {
    for (var i = 0; i < 100; i++) {
      await _plugin.cancel(_reminderIdBase + i);
    }
    _log.debug('cancelled all reminders');
  }

  /// Cancel daily summary.
  static Future<void> cancelDailySummary() async {
    await _plugin.cancel(_dailySummaryId);
    _log.debug('cancelled daily summary');
  }

  /// Show a test notification immediately (for debugging).
  static Future<void> showTestNotification() async {
    await _plugin.show(
      9999,
      'Belly Buddy',
      'Test-Benachrichtigung funktioniert!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannel.id,
          _reminderChannel.name,
          channelDescription: _reminderChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: '/dashboard',
    );
    _log.debug('showed test notification');
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
