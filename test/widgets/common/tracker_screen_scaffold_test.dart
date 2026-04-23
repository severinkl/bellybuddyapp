import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/widgets/common/tracker_screen_scaffold.dart';

void main() {
  group('TrackerScreenScaffold back-arrow', () {
    testWidgets(
      'on a single-entry GoRouter stack, tapping back does not throw and '
      'navigates to /dashboard (reproduces Sentry 39a1efcd6a344b1382ae5eec48590925)',
      (tester) async {
        final router = GoRouter(
          initialLocation: RoutePaths.mealTracker,
          routes: [
            GoRoute(
              path: RoutePaths.dashboard,
              builder: (_, _) =>
                  const Scaffold(body: Center(child: Text('DASHBOARD'))),
            ),
            GoRoute(
              path: RoutePaths.mealTracker,
              builder: (_, _) => const TrackerScreenScaffold(
                title: 'Test',
                showSuccess: false,
                successMessage: '',
                body: SizedBox.shrink(),
              ),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pump();

        // Capture any exception surfaced through FlutterError.onError while
        // we tap the back arrow. A raw context.pop() on a single-entry stack
        // throws GoError synchronously, which the framework reports here.
        final errors = <Object>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details.exception);

        try {
          await tester.tap(find.byIcon(Icons.arrow_back));
          await tester.pumpAndSettle();
        } finally {
          FlutterError.onError = previousOnError;
        }

        expect(
          errors,
          isEmpty,
          reason:
              'Raw context.pop() throws GoError on a single-entry stack. '
              'Use context.popOrGoDashboard() instead.',
        );
        expect(find.text('DASHBOARD'), findsOneWidget);
      },
    );
  });
}
