import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/widgets/common/tracker_screen_scaffold.dart';

GoRouter _buildRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
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
}

// Taps the AppBar back arrow inside a FlutterError.onError capture block
// and returns any exceptions the framework surfaced during the tap. A raw
// `context.pop()` on a single-entry stack throws GoError synchronously,
// which the framework reports through onError.
Future<List<Object>> _tapBackAndCollectErrors(WidgetTester tester) async {
  final errors = <Object>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exception);

  try {
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = previousOnError;
  }

  return errors;
}

void main() {
  group('TrackerScreenScaffold back-arrow', () {
    testWidgets(
      'on a single-entry GoRouter stack, tapping back does not throw and '
      'navigates to /dashboard (reproduces Sentry 39a1efcd6a344b1382ae5eec48590925)',
      (tester) async {
        final router = _buildRouter(initialLocation: RoutePaths.mealTracker);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pump();

        final errors = await _tapBackAndCollectErrors(tester);

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

    testWidgets(
      'on a multi-entry stack, tapping back does not throw and lands on '
      'the previous route',
      (tester) async {
        final router = _buildRouter(initialLocation: RoutePaths.dashboard);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        // Push the tracker so the stack has two entries. The back-arrow
        // should go through Navigator.maybePop; the popOrGoDashboard
        // fallback must NOT fire.
        router.push(RoutePaths.mealTracker);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);

        final errors = await _tapBackAndCollectErrors(tester);

        expect(errors, isEmpty);
        expect(find.text('DASHBOARD'), findsOneWidget);
      },
    );
  });
}
