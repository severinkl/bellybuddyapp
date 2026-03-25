import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../services/local_notification_service.dart';
import '../utils/logger.dart';
import 'profile_provider.dart';

const _log = AppLogger('NotificationProvider');

/// Schedules/cancels notifications whenever the profile changes.
final notificationSyncProvider = Provider<void>((ref) {
  final profileState = ref.watch(profileProvider);

  profileState.whenData((profile) {
    if (profile == null) return;
    _syncNotifications(profile).catchError((e, st) {
      _log.error('failed to sync notifications', e, st);
    });
  });
});

Future<void> _syncNotifications(UserProfile profile) async {
  final timezone = profile.timezone ?? 'Europe/Berlin';

  // Sync logging reminders
  if (profile.remindersEnabled && profile.reminderTimes.isNotEmpty) {
    await LocalNotificationService.scheduleReminders(
      reminderTimes: profile.reminderTimes,
      timezone: timezone,
    );
  } else {
    await LocalNotificationService.cancelReminders();
  }

  // Sync daily summary
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
