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
  bool _showSplash = true;

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
    // Remove native splash once Flutter is rendering
    FlutterNativeSplash.remove();

    await Future.wait([
      Future.delayed(const Duration(milliseconds: 1000)),
      ..._imagesToPreload.map((path) {
        return precacheImage(AssetImage(path), context).catchError((_) {});
      }),
    ]);

    if (mounted) setState(() => _showSplash = false);
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
              AnimatedOpacity(
                opacity: _showSplash ? 1.0 : 0.0,
                duration: AppConstants.animMedium,
                child: Container(
                  color: AppTheme.card,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          AppConstants.mascotHappy,
                          width: 120,
                          height: 120,
                        ),
                        AppConstants.gap16,
                        const Text(
                          'Belly Buddy',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeDisplayLG,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.foreground,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        AppConstants.gap8,
                        const Text(
                          'Dein Bauchgefühl verstehen',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeSubtitle,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.mutedForeground,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
