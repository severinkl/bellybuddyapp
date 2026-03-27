import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'config/firebase_config.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'config/supabase_config.dart';
import 'utils/logger.dart';
import 'firebase_options.dart';
import 'providers/core_providers.dart';
import 'providers/pending_route_provider.dart';
import 'services/notification_service.dart';
import 'services/profile_service.dart';
import 'router/app_router.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  _validateEnv();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  final container = ProviderContainer();
  const log = AppLogger('Main');

  await NotificationService.initialize(
    onNotificationTap: (route) {
      if (route == null) return;
      log.debug('notification tapped → $route');
      container.read(routerProvider).go(route);
    },
    profileService: container.read(profileServiceProvider),
    getUserId: () => container.read(currentUserIdProvider),
  );

  // Check if app was launched by tapping a local notification (terminated state)
  final launchDetails = await FlutterLocalNotificationsPlugin()
      .getNotificationAppLaunchDetails();
  if (launchDetails?.didNotificationLaunchApp == true) {
    final route = launchDetails!.notificationResponse?.payload;
    if (route != null) {
      container.read(pendingRouteProvider.notifier).set(route);
      log.debug('app launched from notification → $route');
    }
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    log.error('FlutterError', details.exception, details.stack);
  };

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BellyBuddyApp(),
    ),
  );
}

void _validateEnv() {
  final missing = <String>[];
  if (SupabaseConfig.url.isEmpty) missing.add('SUPABASE_URL');
  if (SupabaseConfig.anonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
  if (FirebaseConfig.projectId.isEmpty) missing.add('FIREBASE_PROJECT_ID');
  if (missing.isNotEmpty) {
    throw StateError(
      'Missing env vars: ${missing.join(', ')}. '
      'Did you forget --dart-define-from-file=env.json?',
    );
  }
}
