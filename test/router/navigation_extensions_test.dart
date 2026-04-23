import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:belly_buddy/router/navigation_extensions.dart';
import 'package:belly_buddy/router/route_names.dart';

void main() {
  group('BellyBuddyNavigation.popOrGoDashboard', () {
    testWidgets('pops when the stack has more than one entry', (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.dashboard,
        routes: [
          GoRoute(
            path: RoutePaths.dashboard,
            builder: (context, _) => const _DashboardPage(),
          ),
          GoRoute(
            path: RoutePaths.mealTracker,
            builder: (context, _) => const _TrackerPage(),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Push the tracker page so the stack has two entries.
      router.push(RoutePaths.mealTracker);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tracker-page')), findsOneWidget);

      // Tap the tracker's button, which calls popOrGoDashboard.
      await tester.tap(find.byKey(const Key('tracker-pop-button')));
      await tester.pumpAndSettle();

      // Popped back to dashboard rather than replacing via go.
      expect(find.byKey(const Key('dashboard-page')), findsOneWidget);
    });

    testWidgets('goes to /dashboard when the stack has one entry', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: RoutePaths.mealTracker,
        routes: [
          GoRoute(
            path: RoutePaths.dashboard,
            builder: (context, _) => const _DashboardPage(),
          ),
          GoRoute(
            path: RoutePaths.mealTracker,
            builder: (context, _) => const _TrackerPage(),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Stack is single-entry; popOrGoDashboard must fall back to go.
      await tester.tap(find.byKey(const Key('tracker-pop-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard-page')), findsOneWidget);
    });
  });
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('dashboard-page'),
      body: Center(child: Text('Dashboard')),
    );
  }
}

class _TrackerPage extends StatelessWidget {
  const _TrackerPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('tracker-page'),
      body: Center(
        child: ElevatedButton(
          key: const Key('tracker-pop-button'),
          onPressed: context.popOrGoDashboard,
          child: const Text('leave'),
        ),
      ),
    );
  }
}
