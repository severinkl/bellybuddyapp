import '../utils/logger.dart';
import 'local_notification_service.dart';
import 'profile_service.dart';
import 'push_notification_service.dart';

/// Top-level facade that initializes both local and push notification services.
class NotificationService {
  static const _log = AppLogger('NotificationService');

  /// Initialize both local notifications and FCM.
  /// [onNotificationTap] is called when a local notification is tapped,
  /// with the route path as argument.
  /// [profileService] and [getUserId] are injected into [PushNotificationService].
  static Future<void> initialize({
    required void Function(String? route) onNotificationTap,
    required ProfileService profileService,
    required String? Function() getUserId,
  }) async {
    await LocalNotificationService.initialize(
      onNotificationTap: onNotificationTap,
    );
    await PushNotificationService.initialize(
      profileService: profileService,
      getUserId: getUserId,
    );
    _log.debug('all notification services initialized');
  }
}
