import 'package:flutter_riverpod/flutter_riverpod.dart';

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
