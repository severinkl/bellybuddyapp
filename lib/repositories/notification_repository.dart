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
  Future<void> scheduleMealReminders({
    required List<String> mealReminderTimes,
    required String timezone,
    String? buddyName,
  });

  Future<void> cancelMealReminders();

  Future<void> scheduleMoodReminders({
    required List<String> moodReminderTimes,
    required String timezone,
    String? buddyName,
  });

  Future<void> cancelMoodReminders();

  Future<void> cancelAll();
}

/// Production implementation that delegates to [LocalNotificationService].
class LocalNotificationScheduler implements NotificationScheduler {
  @override
  Future<void> scheduleMealReminders({
    required List<String> mealReminderTimes,
    required String timezone,
    String? buddyName,
  }) => LocalNotificationService.scheduleMealReminders(
    mealReminderTimes: mealReminderTimes,
    timezone: timezone,
    buddyName: buddyName,
  );

  @override
  Future<void> cancelMealReminders() =>
      LocalNotificationService.cancelMealReminders();

  @override
  Future<void> scheduleMoodReminders({
    required List<String> moodReminderTimes,
    required String timezone,
    String? buddyName,
  }) => LocalNotificationService.scheduleMoodReminders(
    moodReminderTimes: moodReminderTimes,
    timezone: timezone,
    buddyName: buddyName,
  );

  @override
  Future<void> cancelMoodReminders() =>
      LocalNotificationService.cancelMoodReminders();

  @override
  Future<void> cancelAll() => LocalNotificationService.cancelAll();
}

/// What the OS lets the app do with notifications.
enum NotificationPermission {
  /// Notifications are allowed.
  granted,

  /// Never asked: asking shows the system dialog.
  notDetermined,

  /// Declined or turned off: asking again shows nothing, only the Settings
  /// app can allow them.
  denied,
}

class NotificationRepository {
  final NotificationScheduler _scheduler;
  static const _log = AppLogger('NotificationRepository');

  NotificationRepository(this._scheduler);

  /// Schedules or cancels local notifications based on the user's profile
  /// settings. When [buddyName] is set, reminder bodies use Buddy-voiced copy.
  /// Uses the device timezone (set during initialization).
  Future<void> syncNotifications(
    UserProfile profile, {
    String? buddyName,
  }) async {
    final timezone = tz.local.name;

    if (profile.remindersEnabled && profile.mealReminderTimes.isNotEmpty) {
      await _scheduler.scheduleMealReminders(
        mealReminderTimes: profile.mealReminderTimes,
        timezone: timezone,
        buddyName: buddyName,
      );
    } else {
      await _scheduler.cancelMealReminders();
    }

    if (profile.dailySummaryEnabled && profile.moodReminderTimes.isNotEmpty) {
      await _scheduler.scheduleMoodReminders(
        moodReminderTimes: profile.moodReminderTimes,
        timezone: timezone,
        buddyName: buddyName,
      );
    } else {
      await _scheduler.cancelMoodReminders();
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

  /// The OS notification permission, without asking for it. Unknown (the
  /// check fails) reads as never asked.
  Future<NotificationPermission> permissionStatus() async {
    try {
      return switch (await PushNotificationService.authorizationStatus()) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => NotificationPermission.granted,
        AuthorizationStatus.denied ||
        AuthorizationStatus.deniedPermanently => NotificationPermission.denied,
        AuthorizationStatus.notDetermined =>
          NotificationPermission.notDetermined,
      };
    } catch (e, st) {
      _log.error('reading the notification permission failed', e, st);
      return NotificationPermission.notDetermined;
    }
  }

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
