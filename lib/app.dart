import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/app_theme.dart';
import 'router/app_router.dart';
import 'screens/splash/splash_screen.dart';

class BellyBuddyApp extends ConsumerStatefulWidget {
  const BellyBuddyApp({super.key});

  @override
  ConsumerState<BellyBuddyApp> createState() => _BellyBuddyAppState();
}

class _BellyBuddyAppState extends ConsumerState<BellyBuddyApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

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
      supportedLocales: const [
        Locale('de', 'DE'),
      ],
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
