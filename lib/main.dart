import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'config/firebase_config.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'config/sentry_config.dart';
import 'config/supabase_config.dart';
import 'utils/logger.dart';
import 'firebase_options.dart';
import 'providers/core_providers.dart';
import 'providers/pending_route_provider.dart';
import 'services/notification_service.dart';
import 'services/profile_service.dart';
import 'router/app_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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

  await SentryFlutter.init(
    (options) {
      options.dsn = kReleaseMode ? SentryConfig.dsn : '';
      options.environment = kReleaseMode ? 'production' : 'development';
      options.sendDefaultPii = true;
      options.enableLogs = true;
      options.tracesSampleRate = 0.2;
      // ignore: experimental_member_use — API is stable, pending promotion in Sentry v10
      options.profilesSampleRate = 1.0;
      options.replay.sessionSampleRate = 0.1;
      options.replay.onErrorSampleRate = 1.0;
    },
    appRunner: () => runApp(
      SentryWidget(
        child: UncontrolledProviderScope(
          container: container,
          child: const BellyBuddyApp(),
        ),
      ),
    ),
  );
}

void _validateEnv() {
  final missing = <String>[];
  if (SupabaseConfig.url.isEmpty) missing.add('SUPABASE_URL');
  if (SupabaseConfig.anonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
  if (FirebaseConfig.projectId.isEmpty) missing.add('FIREBASE_PROJECT_ID');
  if (kReleaseMode && SentryConfig.dsn.isEmpty) missing.add('SENTRY_DSN');
  if (missing.isNotEmpty) {
    throw StateError(
      'Missing env vars: ${missing.join(', ')}. '
      'Did you forget --dart-define-from-file=env.json?',
    );
  }
}
