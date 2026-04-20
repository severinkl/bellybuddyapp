// ignore_for_file: invalid_use_of_internal_member
import 'package:belly_buddy/config/splash_screen_config.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/splash_screen_provider.dart';
import 'package:belly_buddy/providers/upgrade_gate_provider.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/router/app_router.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;

import '../../helpers/fakes.dart';

/// Pared-down test host that mirrors the real [BellyBuddyApp] `builder:`
/// arrangement: a [MaterialApp.router] whose builder overlays the splash on
/// top of the router child. When the splash's `onComplete` fires, the splash
/// is removed and the router's current route (post-decision) is visible.
class _SplashTestHost extends ConsumerStatefulWidget {
  const _SplashTestHost();

  @override
  ConsumerState<_SplashTestHost> createState() => _SplashTestHostState();
}

class _SplashTestHostState extends ConsumerState<_SplashTestHost> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final splashConfig = ref.watch(splashConfigProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
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
                minDelay: splashConfig.minDelay,
                animationDuration: splashConfig.animationDuration,
                fadeOutDuration: splashConfig.fadeOutDuration,
                preloadImages: splashConfig.preloadImages,
              ),
          ],
        );
      },
    );
  }
}

List<Override> _baseOverrides({required UpgradeDecision decision}) => [
  // Zero durations so pumpAndSettle advances past splash immediately.
  splashConfigProvider.overrideWithValue(SplashConfig.test),
  // Authenticate so the router's redirect doesn't bounce to /welcome.
  authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
  profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
  // Dashboard repositories — dashboard mounts on the non-hardGate branches
  // and its initState kicks off fetch calls against these providers.
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
  ingredientRepositoryProvider.overrideWithValue(FakeIngredientRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
  // The unit under test.
  upgradeDecisionProvider.overrideWith((_) async => decision),
];

void main() {
  group('Splash upgrade integration', () {
    testWidgets('hardGate → user lands on /upgrade-required after splash', (
      tester,
    ) async {
      final container = ProviderContainer.test(
        overrides: _baseOverrides(decision: UpgradeDecision.hardGate),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _SplashTestHost(),
        ),
      );
      await tester.pumpAndSettle();

      final router = container.read(routerProvider);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        RoutePaths.upgradeRequired,
      );
    });

    testWidgets('softNudge → softNudgePendingProvider is true after splash', (
      tester,
    ) async {
      final container = ProviderContainer.test(
        overrides: _baseOverrides(decision: UpgradeDecision.softNudge),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _SplashTestHost(),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(softNudgePendingProvider), isTrue);
    });

    testWidgets('ok → softNudgePending stays false, stays on dashboard', (
      tester,
    ) async {
      final container = ProviderContainer.test(
        overrides: _baseOverrides(decision: UpgradeDecision.ok),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _SplashTestHost(),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(softNudgePendingProvider), isFalse);
      final router = container.read(routerProvider);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        isNot(RoutePaths.upgradeRequired),
      );
    });
  });
}
