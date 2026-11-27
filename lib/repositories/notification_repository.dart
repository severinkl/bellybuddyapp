import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
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

  /// The daily review's evening notice: once, today at [hour]:[minute].
  Future<void> scheduleDailyReview({
    required int hour,
    required int minute,
    required String timezone,
    String? buddyName,
  });

  Future<void> cancelDailyReview();

  /// The tolerance test's reminders: 09:00 on [reintroDay] and [resultDay].
  Future<void> scheduleTestReminders({
    required String subjectName,
    required DateTime reintroDay,
    required DateTime resultDay,
    required String timezone,
  });

  Future<void> cancelTestReminders();

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
  Future<void> scheduleDailyReview({
    required int hour,
    required int minute,
    required String timezone,
    String? buddyName,
  }) => LocalNotificationService.scheduleDailyReview(
    hour: hour,
    minute: minute,
    timezone: timezone,
    buddyName: buddyName,
  );

  @override
  Future<void> cancelDailyReview() =>
      LocalNotificationService.cancelDailyReview();

  @override
  Future<void> scheduleTestReminders({
    required String subjectName,
    required DateTime reintroDay,
    required DateTime resultDay,
    required String timezone,
  }) => LocalNotificationService.scheduleTestReminders(
    subjectName: subjectName,
    reintroDay: reintroDay,
    resultDay: resultDay,
    timezone: timezone,
  );

  @override
  Future<void> cancelTestReminders() =>
      LocalNotificationService.cancelTestReminders();

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
  /// app can allow them ([NotificationRepository.openNotificationSettings]).
  /// (On Android 13+ a first decline reads so too, though the OS would ask
  /// once more.)
  denied,
}

class NotificationRepository {
  final NotificationScheduler _scheduler;
  static const _log = AppLogger('NotificationRepository');

  /// The iOS Settings page of the app (`UIApplication.openSettingsURLString`).
  static const _iosAppSettingsUrl = 'app-settings:';

  /// Android's way to the app's notification settings (`MainActivity`).
  static const _androidSettings = MethodChannel('belly_buddy/app_settings');

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

  /// Schedules the daily review's evening notice once, today at
  /// [hour]:[minute] in the device time zone (replacing a pending one).
  Future<void> scheduleDailyReview({
    required int hour,
    required int minute,
    String? buddyName,
  }) => _scheduler.scheduleDailyReview(
    hour: hour,
    minute: minute,
    timezone: tz.local.name,
    buddyName: buddyName,
  );

  /// Cancels the daily review's pending evening notice.
  Future<void> cancelDailyReview() => _scheduler.cancelDailyReview();

  /// Schedules the tolerance test's reminders (09:00 on [reintroDay] and
  /// [resultDay], wall-clock dates) in the device time zone, replacing
  /// pending ones.
  Future<void> scheduleTestReminders({
    required String subjectName,
    required DateTime reintroDay,
    required DateTime resultDay,
  }) => _scheduler.scheduleTestReminders(
    subjectName: subjectName,
    reintroDay: reintroDay,
    resultDay: resultDay,
    timezone: tz.local.name,
  );

  /// Cancels the tolerance test's reminders.
  Future<void> cancelTestReminders() => _scheduler.cancelTestReminders();

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

  /// Opens the system settings where the user allows this app's
  /// notifications: on iOS the app's page in the Settings app, on Android
  /// its notification settings. Completes with whether they opened; never
  /// throws.
  Future<bool> openNotificationSettings() async {
    try {
      return switch (defaultTargetPlatform) {
        TargetPlatform.iOS => await launchUrl(
          Uri.parse(_iosAppSettingsUrl),
          mode: LaunchMode.externalApplication,
        ),
        TargetPlatform.android =>
          await _androidSettings.invokeMethod<bool>(
                'openNotificationSettings',
              ) ??
              false,
        _ => false,
      };
    } catch (e, st) {
      _log.error('opening the notification settings failed', e, st);
      return false;
    }
  }

  Future<void> clearToken() => PushNotificationService.clearToken();
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(LocalNotificationScheduler()),
);
