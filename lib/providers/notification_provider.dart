import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../repositories/notification_repository.dart';
import '../utils/logger.dart';
import 'buddy_provider.dart';
import 'profile_provider.dart';

const _log = AppLogger('NotificationProvider');

/// Schedules/cancels notifications whenever the profile changes.
final notificationSyncProvider = Provider<void>((ref) {
  final profileState = ref.watch(profileProvider);
  // Only a rename (or the row appearing) re-syncs; streak changes do not.
  final buddyName = ref.watch(
    buddyProvider.select((s) {
      final status = s.value;
      return status != null && status.hasRow ? status.state.name : null;
    }),
  );

  profileState.whenData((profile) {
    if (profile == null) return;
    ref
        .read(notificationRepositoryProvider)
        .syncNotifications(profile, buddyName: buddyName)
        .catchError((e, st) {
          _log.error('failed to sync notifications', e, st);
        });
  });
});

/// Turns reminders on: asks the OS for notification permissions, remembers
/// that the opt-in was offered ([AppConstants.keyNotificationModalShown], so
/// the dashboard dialog doesn't show again) and stores the outcome as the
/// profile's `pushEnabled`. Returns whether permission was granted.
///
/// Does nothing and returns false while no profile is loaded. Errors (e.g.
/// saving the profile) are rethrown to the caller.
Future<bool> enableReminders(WidgetRef ref) async {
  final profile = ref.read(profileProvider).whenOrNull(data: (p) => p);
  if (profile == null) return false;

  // Read before the async gaps: the caller may unmount during the OS dialog.
  final notifications = ref.read(notificationRepositoryProvider);
  final profiles = ref.read(profileProvider.notifier);

  final granted = await notifications.requestAllPermissions();
  await markNotificationOptInOffered();
  await profiles.updateProfile(profile.copyWith(pushEnabled: granted));
  return granted;
}

/// Remembers that the reminder opt-in was offered
/// ([AppConstants.keyNotificationModalShown]), so the dashboard's opt-in
/// dialog doesn't ask (again).
Future<void> markNotificationOptInOffered() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(AppConstants.keyNotificationModalShown, true);
}
