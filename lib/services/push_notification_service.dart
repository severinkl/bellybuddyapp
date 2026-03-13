import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import 'edge_function_service.dart';

class PushNotificationService {
  static bool _initialized = false;
  static bool _subscribed = false;

  /// Initialize push notification service.
  /// Call this in main.dart after Supabase init.
  static Future<void> initialize({required String oneSignalAppId}) async {
    if (_initialized) return;
    // TODO: Uncomment when onesignal_flutter is added to pubspec.yaml
    // OneSignal.initialize(oneSignalAppId);
    // OneSignal.Notifications.requestPermission(true);
    _initialized = true;
    debugPrint('PushNotificationService: initialized (stub)');
  }

  /// Subscribe user to push notifications and store token.
  static Future<void> subscribe() async {
    if (_subscribed) return;
    final userId = SupabaseService.userId;
    if (userId == null) return;

    try {
      // TODO: Get actual OneSignal player ID
      // final playerId = OneSignal.User.pushSubscription.id;
      // if (playerId == null) return;
      //
      // await SupabaseService.client.from('push_tokens').upsert({
      //   'user_id': userId,
      //   'player_id': playerId,
      //   'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      // });

      _subscribed = true;
      debugPrint('PushNotificationService: subscribed (stub)');
    } catch (e) {
      debugPrint('PushNotificationService: subscribe error: $e');
    }
  }

  /// Unsubscribe user from push notifications.
  static Future<void> unsubscribe() async {
    final userId = SupabaseService.userId;
    if (userId == null) return;

    try {
      // TODO: Remove OneSignal subscription
      // OneSignal.User.pushSubscription.optOut();
      //
      // await SupabaseService.client
      //     .from('push_tokens')
      //     .delete()
      //     .eq('user_id', userId);

      _subscribed = false;
      debugPrint('PushNotificationService: unsubscribed (stub)');
    } catch (e) {
      debugPrint('PushNotificationService: unsubscribe error: $e');
    }
  }

  /// Send a test notification to the current user.
  static Future<void> sendTestNotification() async {
    final userId = SupabaseService.userId;
    if (userId == null) return;

    await EdgeFunctionService.invoke('send-push-notification', body: {
      'user_id': userId,
      'title': 'Test',
      'message': 'Push-Benachrichtigung funktioniert!',
    });
  }

  /// Whether push notifications are currently enabled.
  static bool get isSubscribed => _subscribed;
}
