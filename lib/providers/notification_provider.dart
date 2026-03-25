import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/notification_repository.dart';
import '../utils/logger.dart';
import 'profile_provider.dart';

const _log = AppLogger('NotificationProvider');

/// Schedules/cancels notifications whenever the profile changes.
final notificationSyncProvider = Provider<void>((ref) {
  final profileState = ref.watch(profileProvider);

  profileState.whenData((profile) {
    if (profile == null) return;
    ref
        .read(notificationRepositoryProvider)
        .syncNotifications(profile)
        .catchError((e, st) {
          _log.error('failed to sync notifications', e, st);
        });
  });
});
