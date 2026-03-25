import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';

import '../utils/logger.dart';
import 'profile_service.dart';
import 'supabase_service.dart';

class PushNotificationService {
  static const _log = AppLogger('PushNotificationService');
  static final _messaging = FirebaseMessaging.instance;
  static StreamSubscription<String>? _tokenRefreshSub;

  /// Stream of foreground messages for the UI layer to listen to.
  static Stream<RemoteMessage> get onForegroundMessage =>
      FirebaseMessaging.onMessage;

  /// Stream of notification taps (when app was in background/terminated).
  static Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  /// Initialize FCM: listen for token refresh.
  static Future<void> initialize() async {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen(
      _saveToken,
      onError: (e) => _log.error('token refresh error', e),
    );

    _log.debug('initialized');
  }

  /// Request push notification permission. Returns true if granted.
  static Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    _log.debug('permission: ${settings.authorizationStatus}');

    if (granted) {
      // On iOS, the APNs token must be available before requesting the FCM
      // token. Wait and retry a few times to give the system time to register.
      if (Platform.isIOS) {
        String? apnsToken;
        for (var i = 0; i < 10; i++) {
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) break;
          await Future.delayed(const Duration(milliseconds: 500));
        }
        if (apnsToken == null) {
          // APNs tokens are not available on iOS simulators — this is expected.
          _log.debug(
            'APNs token not available — push notifications require a physical device on iOS',
          );
          return granted;
        }
      }

      try {
        final token = await _messaging.getToken();
        if (token != null) {
          await _saveToken(token);
        }
      } catch (e) {
        _log.error('failed to get FCM token', e);
      }
    }

    return granted;
  }

  /// Get the initial message if the app was opened from a terminated state
  /// via a notification tap.
  static Future<RemoteMessage?> getInitialMessage() async {
    return _messaging.getInitialMessage();
  }

  /// Extract the deep-link route from a RemoteMessage.
  static String? extractRoute(RemoteMessage message) {
    return message.data['route'] as String?;
  }

  /// Save FCM token to the user's profile in Supabase.
  static Future<void> _saveToken(String token) async {
    final userId = SupabaseService.userId;
    if (userId == null) return;

    try {
      await ProfileService.update(userId, {'fcm_token': token});
      _log.debug('saved FCM token');
    } catch (e) {
      _log.error('failed to save FCM token', e);
    }
  }

  /// Clear FCM token from the user's profile (on sign-out).
  static Future<void> clearToken() async {
    final userId = SupabaseService.userId;
    if (userId == null) return;

    try {
      await ProfileService.update(userId, {'fcm_token': null});
      _log.debug('cleared FCM token');
    } catch (e) {
      _log.error('failed to clear FCM token', e);
    }
  }
}
