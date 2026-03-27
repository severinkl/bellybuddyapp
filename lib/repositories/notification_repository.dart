import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/user_profile.dart';
import '../services/local_notification_service.dart';
import '../services/push_notification_service.dart';
import '../utils/logger.dart';

/// Abstract interface for scheduling/cancelling local notifications.
/// Inject this into [NotificationRepository] to enable testability.
abstract class NotificationScheduler {
  Future<void> scheduleReminders({
    required List<String> reminderTimes,
    required String timezone,
  });

  Future<void> cancelReminders();

  Future<void> scheduleDailySummary({
    required String dailySummaryTime,
    required String timezone,
  });

  Future<void> cancelDailySummary();

  Future<void> cancelAll();
}

/// Production implementation that delegates to [LocalNotificationService].
class LocalNotificationScheduler implements NotificationScheduler {
  @override
  Future<void> scheduleReminders({
    required List<String> reminderTimes,
    required String timezone,
  }) => LocalNotificationService.scheduleReminders(
    reminderTimes: reminderTimes,
    timezone: timezone,
  );

  @override
  Future<void> cancelReminders() => LocalNotificationService.cancelReminders();

  @override
  Future<void> scheduleDailySummary({
    required String dailySummaryTime,
    required String timezone,
  }) => LocalNotificationService.scheduleDailySummary(
    dailySummaryTime: dailySummaryTime,
    timezone: timezone,
  );

  @override
  Future<void> cancelDailySummary() =>
      LocalNotificationService.cancelDailySummary();

  @override
  Future<void> cancelAll() => LocalNotificationService.cancelAll();
}

class NotificationRepository {
  final NotificationScheduler _scheduler;
  static const _log = AppLogger('NotificationRepository');

  NotificationRepository(this._scheduler);

  /// Schedules or cancels local notifications based on the user's profile
  /// settings. Uses the device timezone (set during initialization).
  Future<void> syncNotifications(UserProfile profile) async {
    final timezone = tz.local.name;

    if (profile.remindersEnabled && profile.reminderTimes.isNotEmpty) {
      await _scheduler.scheduleReminders(
        reminderTimes: profile.reminderTimes,
        timezone: timezone,
      );
    } else {
      await _scheduler.cancelReminders();
    }

    if (profile.dailySummaryEnabled) {
      await _scheduler.scheduleDailySummary(
        dailySummaryTime: profile.dailySummaryTime,
        timezone: timezone,
      );
    } else {
      await _scheduler.cancelDailySummary();
    }

    _log.debug(
      'synced: reminders=${profile.remindersEnabled}, '
      'summary=${profile.dailySummaryEnabled}, '
      'push=${profile.pushEnabled}',
    );
  }

  Future<void> cancelAll() => _scheduler.cancelAll();

  Stream<RemoteMessage> get onForegroundMessage =>
      PushNotificationService.onForegroundMessage;

  Stream<RemoteMessage> get onMessageOpenedApp =>
      PushNotificationService.onMessageOpenedApp;

  Future<RemoteMessage?> getInitialMessage() =>
      PushNotificationService.getInitialMessage();

  String? extractRoute(RemoteMessage message) =>
      PushNotificationService.extractRoute(message);

  Future<bool> requestPermission() =>
      PushNotificationService.requestPermission();

  /// Request both local and push notification permissions.
  /// Returns true if the OS permission was granted.
  Future<bool> requestAllPermissions() async {
    final granted = await LocalNotificationService.requestPermission();
    if (granted) await PushNotificationService.requestPermission();
    return granted;
  }

  Future<void> clearToken() => PushNotificationService.clearToken();
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(LocalNotificationScheduler()),
);
