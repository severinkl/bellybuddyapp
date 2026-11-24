// ignore_for_file: invalid_use_of_internal_member
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/meal_tracker_provider.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/trackers/meal/meal_tracker_screen.dart';

import '../../../helpers/app_host.dart';
import '../../../helpers/fakes.dart';

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/meal-tracker',
    routes: [
      GoRoute(
        path: '/meal-tracker',
        builder: (_, _) => const MealTrackerScreen(),
      ),
      GoRoute(
        path: RoutePaths.drinkTracker,
        builder: (_, state) {
          final extra = state.extra as DateTime?;
          return Scaffold(
            body: Text('drink-extra:${extra?.toIso8601String() ?? "null"}'),
          );
        },
      ),
    ],
  );
}

List<Override> _overrides() => [
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
  ingredientRepositoryProvider.overrideWithValue(FakeIngredientRepository()),
  mealMediaRepositoryProvider.overrideWithValue(FakeMealMediaRepository()),
  buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
];

Future<ProviderContainer> _pumpMealTracker(WidgetTester tester) async {
  final container = ProviderContainer.test(overrides: _overrides());
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: germanRouterApp(_buildRouter()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('MealTrackerScreen → DrinkTrackerScreen handoff', () {
    testWidgets(
      'form-button "Trinken eintragen" forwards state.trackedAt as extra',
      (tester) async {
        final container = await _pumpMealTracker(tester);

        final fixed = DateTime(2026, 5, 1, 12, 30);
        container.read(mealTrackerProvider.notifier).setTrackedAt(fixed);
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(MealTrackerScreen.drinkTrackerButtonKey),
        );
        await tester.tap(find.byKey(MealTrackerScreen.drinkTrackerButtonKey));
        await tester.pumpAndSettle();

        expect(
          find.text('drink-extra:${fixed.toIso8601String()}'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'success-card "Trinken eintragen" forwards state.trackedAt as extra',
      (tester) async {
        final container = await _pumpMealTracker(tester);

        final fixed = DateTime(2025, 11, 17, 8, 5);
        final notifier = container.read(mealTrackerProvider.notifier);
        notifier.setTrackedAt(fixed);
        notifier.markShowSuccess();
        // The success screen's Buddy animates forever: no pumpAndSettle.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        await tester.tap(find.text('Trinken eintragen'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.text('drink-extra:${fixed.toIso8601String()}'),
          findsOneWidget,
        );
      },
    );

    GoRouter originRouter() => GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('home-sentinel')),
        ),
        GoRoute(
          path: '/meal-tracker',
          builder: (_, _) => const MealTrackerScreen(),
        ),
        GoRoute(
          path: RoutePaths.drinkTracker,
          // Stands in for the drink tracker: closes with true once a drink
          // was saved, without a result when left unsaved.
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => context.pop(true),
                  child: const Text('drink-saved'),
                ),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('drink-back'),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    Future<void> openMealSuccess(WidgetTester tester, GoRouter router) async {
      final container = ProviderContainer.test(overrides: _overrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: germanRouterApp(router),
        ),
      );
      await tester.pumpAndSettle();
      router.push('/meal-tracker');
      await tester.pumpAndSettle();
      container.read(mealTrackerProvider.notifier).markShowSuccess();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.text('Trinken eintragen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('a drink saved from the meal success screen returns to where '
        'the meal was started', (tester) async {
      final router = originRouter();
      await openMealSuccess(tester, router);

      await tester.tap(find.text('drink-saved'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('home-sentinel'), findsOneWidget);
      expect(find.text('Mahlzeit gespeichert!'), findsNothing);
    });

    testWidgets('leaving the drink tracker unsaved returns to the meal '
        'success screen', (tester) async {
      final router = originRouter();
      await openMealSuccess(tester, router);

      await tester.tap(find.text('drink-back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Mahlzeit gespeichert!'), findsOneWidget);
    });

    testWidgets('the success screen offers to save the meal as a recipe', (
      tester,
    ) async {
      final container = await _pumpMealTracker(tester);
      container.read(mealTrackerProvider.notifier).markShowSuccess();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(
        find.text(
          'Speichere diese Mahlzeit als Rezept, um sie später schneller '
          'wieder einzutragen.',
        ),
        findsOneWidget,
      );
    });
  });
}
