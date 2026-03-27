import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/profile_provider.dart';
import 'router/app_router.dart';
import 'screens/splash/splash_screen.dart';
import 'main.dart' show consumePendingNotificationRoute;
import 'repositories/notification_repository.dart';
import 'utils/logger.dart';

class BellyBuddyApp extends ConsumerStatefulWidget {
  const BellyBuddyApp({super.key});

  @override
  ConsumerState<BellyBuddyApp> createState() => _BellyBuddyAppState();
}

class _BellyBuddyAppState extends ConsumerState<BellyBuddyApp> {
  static const _log = AppLogger('BellyBuddy');
  bool _showSplash = true;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  @override
  void initState() {
    super.initState();
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) {
      _log.debug('authenticated on start, user=$userId');
      Future.microtask(() => ref.read(profileProvider.notifier).fetchProfile());
    } else {
      _log.debug('no authenticated user on start');
    }

    // Navigate to route from local notification that launched the app
    final pendingRoute = consumePendingNotificationRoute();
    if (pendingRoute != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(routerProvider).go(pendingRoute);
      });
    }

    final notificationRepo = ref.read(notificationRepositoryProvider);

    // Handle push notification taps from background state
    _openedAppSub = notificationRepo.onMessageOpenedApp.listen((msg) {
      final route = notificationRepo.extractRoute(msg);
      if (route != null) {
        ref.read(routerProvider).go(route);
      }
    });

    // Listen for foreground push messages → show snackbar
    _foregroundSub = notificationRepo.onForegroundMessage.listen((msg) {
      final title = msg.notification?.title;
      final body = msg.notification?.body;
      final route = notificationRepo.extractRoute(msg);

      if (title != null || body != null) {
        final context = ref.read(navigatorKeyProvider).currentContext;
        if (context != null) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(body ?? title ?? ''),
              action: route != null
                  ? SnackBarAction(
                      label: 'Anzeigen',
                      onPressed: () => ref.read(routerProvider).go(route),
                    )
                  : null,
            ),
          );
        }
      }
    });

    // Handle initial message (app opened from terminated state via notification)
    notificationRepo.getInitialMessage().then((msg) {
      if (msg != null) {
        final route = notificationRepo.extractRoute(msg);
        if (route != null) {
          // Delay to ensure router is ready
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) ref.read(routerProvider).go(route);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _foregroundSub?.cancel();
    _openedAppSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Activate notification sync provider
    ref.watch(notificationSyncProvider);

    ref.listen<bool>(isAuthenticatedProvider, (prev, next) {
      _log.debug('auth changed $prev → $next');
      if (next) {
        ref.read(profileProvider.notifier).fetchProfile();
      } else {
        ref.read(profileProvider.notifier).reset();
        ref.read(notificationRepositoryProvider).cancelAll();
        ref.read(notificationRepositoryProvider).clearToken();
      }
    });

    return MaterialApp.router(
      title: 'Belly Buddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de', 'DE')],
      locale: const Locale('de', 'DE'),
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            if (_showSplash)
              SplashScreen(
                onComplete: () {
                  if (mounted) setState(() => _showSplash = false);
                },
              ),
          ],
        );
      },
    );
  }
}
