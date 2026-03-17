import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/profile_provider.dart';
import 'router/app_router.dart';
import 'screens/splash/splash_screen.dart';
import 'services/supabase_service.dart';
import 'utils/logger.dart';

class BellyBuddyApp extends ConsumerStatefulWidget {
  const BellyBuddyApp({super.key});

  @override
  ConsumerState<BellyBuddyApp> createState() => _BellyBuddyAppState();
}

class _BellyBuddyAppState extends ConsumerState<BellyBuddyApp> {
  static const _log = AppLogger('BellyBuddy');
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // Initial profile fetch for already-authenticated users.
    // This handles the case where currentUser is already available synchronously.
    if (SupabaseService.isAuthenticated) {
      _log.debug('authenticated on start, user=${SupabaseService.userId}');
      Future.microtask(() => ref.read(profileProvider.notifier).fetchProfile());
    } else {
      _log.debug('no authenticated user on start');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Reactively fetch/reset profile when auth state changes.
    // This handles: (a) session restored asynchronously after initState,
    // (b) login from auth screen, (c) logout.
    ref.listen<bool>(isAuthenticatedProvider, (prev, next) {
      _log.debug('auth changed $prev → $next');
      if (next) {
        ref.read(profileProvider.notifier).fetchProfile();
      } else {
        ref.read(profileProvider.notifier).reset();
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
