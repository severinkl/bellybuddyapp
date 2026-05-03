// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/meal_tracker_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/trackers/meal/meal_tracker_screen.dart';

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
  currentUserIdProvider.overrideWithValue('test-user'),
];

Future<ProviderContainer> _pumpMealTracker(WidgetTester tester) async {
  final container = ProviderContainer.test(overrides: _overrides());
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: _buildRouter(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de', 'DE')],
        locale: const Locale('de', 'DE'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('MealTrackerScreen → DrinkTrackerScreen handoff', () {
    testWidgets(
      'form-button "Getränk tracken" forwards state.trackedAt as extra',
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
      'success-card "Getränk hinzufügen" forwards state.trackedAt as extra',
      (tester) async {
        final container = await _pumpMealTracker(tester);

        final fixed = DateTime(2025, 11, 17, 8, 5);
        final notifier = container.read(mealTrackerProvider.notifier);
        notifier.setTrackedAt(fixed);
        notifier.markShowSuccess();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Getränk hinzufügen'));
        await tester.pumpAndSettle();

        expect(
          find.text('drink-extra:${fixed.toIso8601String()}'),
          findsOneWidget,
        );
      },
    );
  });
}
