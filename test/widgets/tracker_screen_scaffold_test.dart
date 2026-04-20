import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:belly_buddy/widgets/common/bb_success_overlay.dart';
import 'package:belly_buddy/widgets/common/tracker_screen_scaffold.dart';

// Helper: build a GoRouter with a "home" route and a tracker route that
// renders [TrackerScreenScaffold] in its success state. Lets us verify the
// default onSuccessDismissed pops back to whatever pushed the tracker.
GoRouter _router({required bool showSuccess}) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('HOME_MARKER'))),
      ),
      GoRoute(
        path: '/tracker',
        builder: (_, _) => TrackerScreenScaffold(
          trackerKey: const Key('test_tracker'),
          title: 'Test',
          showSuccess: showSuccess,
          successMessage: 'Gespeichert!',
          // Pass a mascot so auto-dismiss stays off and we control the tap.
          successMascotAsset: 'test',
          body: const SizedBox.shrink(),
        ),
      ),
    ],
  );
}

void main() {
  group('TrackerScreenScaffold default onSuccessDismissed', () {
    testWidgets('tapping the success overlay pops back to the pushing route', (
      tester,
    ) async {
      final router = _router(showSuccess: true);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Push the tracker on top of home.
      router.push('/tracker');
      await tester.pumpAndSettle();

      // Sanity: home is no longer visible, the overlay is.
      expect(find.text('HOME_MARKER'), findsNothing);
      expect(find.byType(BbSuccessOverlay), findsOneWidget);

      // Tap the overlay to dismiss.
      await tester.tap(find.byType(BbSuccessOverlay));
      await tester.pumpAndSettle();

      // Pop should have fired: back on home.
      expect(find.text('HOME_MARKER'), findsOneWidget);
      expect(find.byType(BbSuccessOverlay), findsNothing);
    });
  });
}
