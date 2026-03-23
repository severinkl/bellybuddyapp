import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/app_theme.dart';
import 'config/constants.dart';
import 'providers/auth_provider.dart';
import 'providers/profile_provider.dart';
import 'router/app_router.dart';
import 'services/supabase_service.dart';
import 'utils/logger.dart';

class BellyBuddyApp extends ConsumerStatefulWidget {
  const BellyBuddyApp({super.key});

  @override
  ConsumerState<BellyBuddyApp> createState() => _BellyBuddyAppState();
}

class _BellyBuddyAppState extends ConsumerState<BellyBuddyApp> {
  static const _log = AppLogger('BellyBuddy');

  static const _imagesToPreload = [
    AppConstants.mascotHappy,
    AppConstants.mascotCool,
    AppConstants.mascotProfessor,
    AppConstants.mascotWink,
    AppConstants.mascotEnergetic,
    AppConstants.mascotNervous,
    AppConstants.mascotClueless,
    AppConstants.mascotSad,
    AppConstants.mascotBored,
    AppConstants.mascotClear,
    AppConstants.mascotUnfocused,
    AppConstants.mascotStressed,
    AppConstants.mascotInLove,
    AppConstants.mascotZen,
    AppConstants.mascotBloatingStomach,
    AppConstants.mascotHappyStomach,
    AppConstants.mascotFlatulance,
    AppConstants.mascotCramp,
    AppConstants.mascotNoCramp,
    AppConstants.mascotFullness,
    AppConstants.susiPhone,
    AppConstants.fuerDichCard,
    AppConstants.toiletPaperIcon,
  ];

  bool _precached = false;

  @override
  void initState() {
    super.initState();
    if (SupabaseService.isAuthenticated) {
      _log.debug('authenticated on start, user=${SupabaseService.userId}');
      Future.microtask(() => ref.read(profileProvider.notifier).fetchProfile());
    } else {
      _log.debug('no authenticated user on start');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      _precacheAndRemoveSplash();
    }
  }

  Future<void> _precacheAndRemoveSplash() async {
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 500)),
      ..._imagesToPreload.map((path) {
        return precacheImage(AssetImage(path), context).catchError((_) {});
      }),
    ]);
    FlutterNativeSplash.remove();
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
    );
  }
}
