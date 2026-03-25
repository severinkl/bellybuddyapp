import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../services/local_notification_service.dart';
import '../utils/logger.dart';

class NotificationRepository {
  static const _log = AppLogger('NotificationRepository');

  /// Schedules or cancels local notifications based on the user's profile
  /// settings.
  Future<void> syncNotifications(UserProfile profile) async {
    final timezone = profile.timezone ?? 'Europe/Berlin';

    if (profile.remindersEnabled && profile.reminderTimes.isNotEmpty) {
      await LocalNotificationService.scheduleReminders(
        reminderTimes: profile.reminderTimes,
        timezone: timezone,
      );
    } else {
      await LocalNotificationService.cancelReminders();
    }

    if (profile.dailySummaryEnabled) {
      await LocalNotificationService.scheduleDailySummary(
        dailySummaryTime: profile.dailySummaryTime,
        timezone: timezone,
      );
    } else {
      await LocalNotificationService.cancelDailySummary();
    }

    _log.debug(
      'synced: reminders=${profile.remindersEnabled}, '
      'summary=${profile.dailySummaryEnabled}, '
      'push=${profile.pushEnabled}',
    );
  }

  Future<void> cancelAll() => LocalNotificationService.cancelAll();
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(),
);
