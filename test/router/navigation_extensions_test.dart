import 'dart:async';

import 'package:material_ui/material_ui.dart';
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

  group('BellyBuddyNavigation.popOr', () {
    testWidgets('goes to the location when nothing is below', (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.mealTracker,
        routes: [
          GoRoute(
            path: RoutePaths.discover,
            builder: (_, _) => const Text('discover'),
          ),
          GoRoute(
            path: RoutePaths.mealTracker,
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.popOr(RoutePaths.discover),
                child: const Text('leave'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('leave'));
      await tester.pumpAndSettle();

      expect(find.text('discover'), findsOneWidget);
    });

    testWidgets('pops when something is below', (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.dashboard,
        routes: [
          GoRoute(
            path: RoutePaths.dashboard,
            builder: (context, _) => const _DashboardPage(),
          ),
          GoRoute(
            path: RoutePaths.discover,
            builder: (_, _) => const Text('discover'),
          ),
          GoRoute(
            path: RoutePaths.mealTracker,
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.popOr(RoutePaths.discover),
                child: const Text('leave'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      unawaited(router.push(RoutePaths.mealTracker));
      await tester.pumpAndSettle();
      await tester.tap(find.text('leave'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard-page')), findsOneWidget);
      expect(find.text('discover'), findsNothing);
    });
  });

  group('BellyBuddyNavigation.openRecipe', () {
    testWidgets('openRecipe pushes /collection/<id>', (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.dashboard,
        routes: [
          GoRoute(
            path: RoutePaths.dashboard,
            builder: (context, _) => Scaffold(
              body: ElevatedButton(
                key: const Key('open-recipe'),
                onPressed: () => context.openRecipe('abc'),
                child: const Text('open'),
              ),
            ),
          ),
          GoRoute(
            path: RoutePaths.collectionRecipe,
            builder: (_, state) => Text('recipe:${state.pathParameters['id']}'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-recipe')));
      await tester.pumpAndSettle();

      expect(find.text('recipe:abc'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/collection/abc',
      );
      // Pushed over the page it was opened from.
      expect(router.canPop(), isTrue);
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
