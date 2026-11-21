// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

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
import 'package:belly_buddy/screens/upgrade/upgrade_required_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;

import '../../helpers/fakes.dart';

/// Pared-down test host that mirrors the real [BellyBuddyApp]: the app root
/// owns the upgrade decision via [listenForUpgradeDecision], and a
/// [MaterialApp.router] builder overlays the splash on top of the router
/// child. When the splash's `onComplete` fires, the splash is removed and the
/// router's current route is visible.
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
    listenForUpgradeDecision(ref);

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

List<Override> _baseOverrides({
  UpgradeDecision? decision,
  Future<UpgradeDecision>? pending,
}) => [
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
  // The unit under test. `pending` lets a test resolve the decision after
  // the splash is gone (a slow app_config fetch).
  upgradeDecisionProvider.overrideWith(
    (_) => pending ?? Future.value(decision),
  ),
];

String _currentPath(ProviderContainer container) =>
    container.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

Future<ProviderContainer> _pumpHost(
  WidgetTester tester,
  List<Override> overrides,
) async {
  final container = ProviderContainer.test(overrides: overrides);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const _SplashTestHost(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('Splash upgrade integration', () {
    testWidgets('hardGate → user lands on /upgrade-required after splash', (
      tester,
    ) async {
      final container = await _pumpHost(
        tester,
        _baseOverrides(decision: UpgradeDecision.hardGate),
      );

      expect(_currentPath(container), RoutePaths.upgradeRequired);
      expect(find.byType(UpgradeRequiredScreen), findsOneWidget);
    });

    testWidgets('hardGate resolving after the splash is gone still lands on '
        '/upgrade-required', (tester) async {
      final decision = Completer<UpgradeDecision>();
      final container = await _pumpHost(
        tester,
        _baseOverrides(pending: decision.future),
      );

      // Splash finished while the decision was still in flight.
      expect(find.byType(SplashScreen), findsNothing);
      expect(_currentPath(container), RoutePaths.dashboard);

      decision.complete(UpgradeDecision.hardGate);
      await tester.pumpAndSettle();

      expect(container.read(hardGateActiveProvider), isTrue);
      expect(_currentPath(container), RoutePaths.upgradeRequired);
      expect(find.byType(UpgradeRequiredScreen), findsOneWidget);
    });

    testWidgets('router.go while gated stays on /upgrade-required', (
      tester,
    ) async {
      final container = await _pumpHost(
        tester,
        _baseOverrides(decision: UpgradeDecision.hardGate),
      );
      final router = container.read(routerProvider);

      // The routes app.dart navigates to on notification taps / pendingRoute.
      for (final route in [
        RoutePaths.dashboard,
        RoutePaths.recommendations,
        RoutePaths.welcome,
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(_currentPath(container), RoutePaths.upgradeRequired);
      }
      expect(find.byType(UpgradeRequiredScreen), findsOneWidget);
    });

    testWidgets('softNudge → dialog shown once on the dashboard', (
      tester,
    ) async {
      final container = await _pumpHost(
        tester,
        _baseOverrides(decision: UpgradeDecision.softNudge),
      );

      expect(_currentPath(container), RoutePaths.dashboard);
      expect(find.text('Update verfügbar'), findsOneWidget);
      expect(container.read(softNudgePendingProvider), isFalse);
    });

    testWidgets(
      'softNudge resolving after the dashboard mounted shows the dialog '
      'exactly once',
      (tester) async {
        final decision = Completer<UpgradeDecision>();
        final container = await _pumpHost(
          tester,
          _baseOverrides(pending: decision.future),
        );
        expect(find.byType(SplashScreen), findsNothing);
        expect(_currentPath(container), RoutePaths.dashboard);
        expect(find.text('Update verfügbar'), findsNothing);

        decision.complete(UpgradeDecision.softNudge);
        await tester.pumpAndSettle();

        expect(find.text('Update verfügbar'), findsOneWidget);
        expect(container.read(softNudgePendingProvider), isFalse);

        await tester.tap(find.text('Später'));
        await tester.pumpAndSettle();
        expect(find.text('Update verfügbar'), findsNothing);

        // Navigating away and back re-mounts nothing that re-shows it.
        container.read(routerProvider).go(RoutePaths.diary);
        await tester.pumpAndSettle();
        container.read(routerProvider).go(RoutePaths.dashboard);
        await tester.pumpAndSettle();
        expect(find.text('Update verfügbar'), findsNothing);
      },
    );

    testWidgets('ok → no gate, no nudge, /upgrade-required unreachable', (
      tester,
    ) async {
      final container = await _pumpHost(
        tester,
        _baseOverrides(decision: UpgradeDecision.ok),
      );

      expect(container.read(softNudgePendingProvider), isFalse);
      expect(container.read(hardGateActiveProvider), isFalse);
      expect(_currentPath(container), RoutePaths.dashboard);
      expect(find.text('Update verfügbar'), findsNothing);

      container.read(routerProvider).go(RoutePaths.upgradeRequired);
      await tester.pumpAndSettle();
      expect(_currentPath(container), RoutePaths.dashboard);
    });
  });
}
