import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:belly_buddy/widgets/common/bb_success_overlay.dart';
import 'package:belly_buddy/widgets/common/tracker_screen_scaffold.dart';

// BbSuccessOverlay's behavior depends on whether a mascot is set:
//   - hasMascot=true:  tap-to-dismiss enabled, auto-dismiss disabled.
//   - hasMascot=false: tap-to-dismiss disabled, auto-dismiss enabled.
// We want tap-to-dismiss so the test can trigger onDismissed deterministically.
// The string is only used as an asset key; MascotImage fails to resolve it
// (Flutter renders an error box in tests), which is fine for this test.
const _kTestMascotAsset = 'test-asset-enables-tap-dismiss';

Widget _homeScreen() =>
    const Scaffold(body: Center(child: Text('HOME_MARKER')));

Widget _successScaffold({VoidCallback? onSuccessDismissed}) {
  return TrackerScreenScaffold(
    trackerKey: const Key('test_tracker'),
    title: 'Test',
    showSuccess: true,
    successMessage: 'Gespeichert!',
    successMascotAsset: _kTestMascotAsset,
    onSuccessDismissed: onSuccessDismissed,
    body: const SizedBox.shrink(),
  );
}

void main() {
  group('TrackerScreenScaffold default onSuccessDismissed', () {
    testWidgets('tapping the success overlay pops back to the pushing route', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(path: '/home', builder: (_, _) => _homeScreen()),
          GoRoute(path: '/tracker', builder: (_, _) => _successScaffold()),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.push('/tracker');
      await tester.pumpAndSettle();

      expect(find.text('HOME_MARKER'), findsNothing);
      expect(find.byType(BbSuccessOverlay), findsOneWidget);

      await tester.tap(find.byType(BbSuccessOverlay));
      await tester.pumpAndSettle();

      expect(find.text('HOME_MARKER'), findsOneWidget);
      expect(find.byType(BbSuccessOverlay), findsNothing);
    });

    testWidgets(
      'deep-link into tracker with empty stack falls back to /dashboard',
      (tester) async {
        // Simulates a push notification / universal link that opens the
        // tracker directly with no parent route underneath.
        var dashboardVisited = false;
        final router = GoRouter(
          initialLocation: '/tracker',
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, _) {
                dashboardVisited = true;
                return const Scaffold(body: Center(child: Text('DASHBOARD')));
              },
            ),
            GoRoute(path: '/tracker', builder: (_, _) => _successScaffold()),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.byType(BbSuccessOverlay), findsOneWidget);

        await tester.tap(find.byType(BbSuccessOverlay));
        await tester.pumpAndSettle();

        expect(dashboardVisited, isTrue);
        expect(find.text('DASHBOARD'), findsOneWidget);
      },
    );
  });

  group('TrackerScreenScaffold onSuccessDismissed override', () {
    testWidgets('custom onDismissed replaces the default pop behavior', (
      tester,
    ) async {
      // Mirrors the gut-feeling pattern: the screen supplies its own
      // canPop-guarded onDismissed. Verify the default is NOT invoked
      // when an override is provided.
      var customInvoked = false;
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(path: '/home', builder: (_, _) => _homeScreen()),
          GoRoute(
            path: '/tracker',
            builder: (_, _) => _successScaffold(
              onSuccessDismissed: () => customInvoked = true,
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.push('/tracker');
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BbSuccessOverlay));
      await tester.pumpAndSettle();

      expect(customInvoked, isTrue);
      // Override is in effect: default-pop did NOT fire, so we are still
      // on the tracker route.
      expect(find.text('HOME_MARKER'), findsNothing);
    });
  });
}
