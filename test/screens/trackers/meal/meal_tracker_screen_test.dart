// ignore_for_file: invalid_use_of_internal_member
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/meal_tracker_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/screens/trackers/meal/meal_tracker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/src/internals.dart' show Override;

import '../../../helpers/fakes.dart';
import '../../../helpers/riverpod_helpers.dart';

/// Builds a 2-route GoRouter so the tracker screen (reached via /edit) can
/// `context.pop()` back to a sentinel home screen. This lets tests assert on
/// the pop behaviour without mocking the navigator directly.
GoRouter _buildRouter(String mealId) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('home-sentinel')),
      ),
      GoRoute(
        path: '/edit',
        builder: (_, _) => MealTrackerScreen(mealId: mealId),
      ),
    ],
  );
}

Future<void> _pumpEditScreen(
  WidgetTester tester, {
  required String mealId,
  required List<Override> overrides,
}) async {
  final router = _buildRouter(mealId);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: ProviderContainer.test(overrides: overrides),
      child: MaterialApp.router(
        routerConfig: router,
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
  // Push from home → edit so the tracker screen has something to pop back to.
  await tester.pumpAndSettle();
  router.push('/edit');
  await tester.pumpAndSettle();
}

MealEntry _seededMeal({
  String id = 'meal-42',
  String title = 'Pasta Bolognese',
  List<String> ingredients = const ['Nudeln', 'Tomatensoße'],
}) => MealEntry(
  id: id,
  trackedAt: DateTime(2026, 4, 10, 12, 30),
  title: title,
  ingredients: ingredients,
);

void main() {
  group('MealTrackerScreen edit mode', () {
    testWidgets('seeds the form from the meal', (tester) async {
      final meal = _seededMeal();
      final fakeEntries = FakeEntryRepository();

      await _pumpEditScreen(
        tester,
        mealId: 'meal-42',
        overrides: [
          entriesProviderSeededWith([meal]),
          entryRepositoryProvider.overrideWithValue(fakeEntries),
          ingredientRepositoryProvider.overrideWithValue(
            FakeIngredientRepository(),
          ),
          mealMediaRepositoryProvider.overrideWithValue(
            FakeMealMediaRepository(),
          ),
          currentUserIdProvider.overrideWithValue('user-1'),
        ],
      );

      // Title text is rendered inside the AppBar titleWidget.
      expect(find.text('Pasta Bolognese'), findsWidgets);
      // Ingredients appear as chips in the ingredient search section.
      expect(find.text('Nudeln'), findsOneWidget);
      expect(find.text('Tomatensoße'), findsOneWidget);
    });

    testWidgets(
      'save with no changes pops silently without calling updateMeal',
      (tester) async {
        final meal = _seededMeal();
        final fakeEntries = FakeEntryRepository();

        await _pumpEditScreen(
          tester,
          mealId: 'meal-42',
          overrides: [
            entriesProviderSeededWith([meal]),
            entryRepositoryProvider.overrideWithValue(fakeEntries),
            ingredientRepositoryProvider.overrideWithValue(
              FakeIngredientRepository(),
            ),
            mealMediaRepositoryProvider.overrideWithValue(
              FakeMealMediaRepository(),
            ),
            currentUserIdProvider.overrideWithValue('user-1'),
          ],
        );

        await tester.ensureVisible(
          find.byKey(MealTrackerScreen.mealEditSaveKey),
        );
        await tester.tap(find.byKey(MealTrackerScreen.mealEditSaveKey));
        await tester.pumpAndSettle();

        // Popped back to the home sentinel.
        expect(find.byType(MealTrackerScreen), findsNothing);
        expect(find.text('home-sentinel'), findsOneWidget);
        // No network round-trip happened.
        expect(fakeEntries.updatedMeals, isEmpty);
        expect(fakeEntries.addedMeals, isEmpty);
      },
    );

    testWidgets(
      'save after a title change calls updateMeal with the new title and pops',
      (tester) async {
        final meal = _seededMeal();
        final fakeEntries = FakeEntryRepository();

        await _pumpEditScreen(
          tester,
          mealId: 'meal-42',
          overrides: [
            entriesProviderSeededWith([meal]),
            entryRepositoryProvider.overrideWithValue(fakeEntries),
            ingredientRepositoryProvider.overrideWithValue(
              FakeIngredientRepository(),
            ),
            mealMediaRepositoryProvider.overrideWithValue(
              FakeMealMediaRepository(),
            ),
            currentUserIdProvider.overrideWithValue('user-1'),
          ],
        );

        // Enter edit mode on the title by tapping the existing title row.
        await tester.tap(find.byKey(MealTrackerScreen.mealTrackerTitleKey));
        await tester.pumpAndSettle();

        // Replace the title text in the now-visible TextField.
        await tester.enterText(find.byType(TextField).first, 'Pasta Carbonara');
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(MealTrackerScreen.mealEditSaveKey),
        );
        await tester.tap(find.byKey(MealTrackerScreen.mealEditSaveKey));
        await tester.pumpAndSettle();

        expect(fakeEntries.updatedMeals, hasLength(1));
        final saved = fakeEntries.updatedMeals.single;
        expect(saved.id, 'meal-42');
        expect(saved.title, 'Pasta Carbonara');
        expect(fakeEntries.addedMeals, isEmpty);

        // Screen popped.
        expect(find.byType(MealTrackerScreen), findsNothing);
        expect(find.text('home-sentinel'), findsOneWidget);
      },
    );

    testWidgets(
      'save after an ingredient change persists the new list and pops',
      (tester) async {
        final meal = _seededMeal();
        final fakeEntries = FakeEntryRepository();

        await _pumpEditScreen(
          tester,
          mealId: 'meal-42',
          overrides: [
            entriesProviderSeededWith([meal]),
            entryRepositoryProvider.overrideWithValue(fakeEntries),
            ingredientRepositoryProvider.overrideWithValue(
              FakeIngredientRepository(),
            ),
            mealMediaRepositoryProvider.overrideWithValue(
              FakeMealMediaRepository(),
            ),
            currentUserIdProvider.overrideWithValue('user-1'),
          ],
        );

        // IngredientSearch has a search-field; adding bypasses search by
        // calling the notifier directly via the container — simpler than
        // driving the autocomplete UI in this test.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MealTrackerScreen)),
          listen: false,
        );
        container.read(mealTrackerProvider.notifier).addIngredient('Parmesan');
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(MealTrackerScreen.mealEditSaveKey),
        );
        await tester.tap(find.byKey(MealTrackerScreen.mealEditSaveKey));
        await tester.pumpAndSettle();

        expect(fakeEntries.updatedMeals, hasLength(1));
        final saved = fakeEntries.updatedMeals.single;
        expect(saved.id, 'meal-42');
        expect(
          saved.ingredients,
          containsAll(['Nudeln', 'Tomatensoße', 'Parmesan']),
        );
        expect(fakeEntries.addedMeals, isEmpty);
        expect(find.text('home-sentinel'), findsOneWidget);
      },
    );

    testWidgets('edit-mode save stays on screen when updateMeal fails', (
      tester,
    ) async {
      final meal = _seededMeal();
      final failingEntries = FakeEntryRepository(throwOnUpdate: true);

      await _pumpEditScreen(
        tester,
        mealId: 'meal-42',
        overrides: [
          entriesProviderSeededWith([meal]),
          entryRepositoryProvider.overrideWithValue(failingEntries),
          ingredientRepositoryProvider.overrideWithValue(
            FakeIngredientRepository(),
          ),
          mealMediaRepositoryProvider.overrideWithValue(
            FakeMealMediaRepository(),
          ),
          currentUserIdProvider.overrideWithValue('user-1'),
        ],
      );

      // Force a dirty state so save attempts a write.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MealTrackerScreen)),
        listen: false,
      );
      container.read(mealTrackerProvider.notifier).addIngredient('Parmesan');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(MealTrackerScreen.mealEditSaveKey));
      await tester.tap(find.byKey(MealTrackerScreen.mealEditSaveKey));
      await tester.pumpAndSettle();

      // Error SnackBar surfaced, screen did NOT pop.
      expect(find.text('Fehler beim Speichern.'), findsOneWidget);
      expect(find.byType(MealTrackerScreen), findsOneWidget);
      expect(find.text('home-sentinel'), findsNothing);
    });

    testWidgets(
      'unknown mealId renders the "Mahlzeit nicht gefunden" fallback',
      (tester) async {
        await _pumpEditScreen(
          tester,
          mealId: 'gone-meal',
          overrides: [
            entriesProviderSeededWith(const []),
            entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
            ingredientRepositoryProvider.overrideWithValue(
              FakeIngredientRepository(),
            ),
            mealMediaRepositoryProvider.overrideWithValue(
              FakeMealMediaRepository(),
            ),
            currentUserIdProvider.overrideWithValue('user-1'),
          ],
        );

        expect(find.text('Mahlzeit nicht gefunden'), findsOneWidget);
      },
    );
  });

  group('MealTrackerScreen discard-changes guard', () {
    List<Override> defaultOverrides(MealEntry meal) => [
      entriesProviderSeededWith([meal]),
      entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
      ingredientRepositoryProvider.overrideWithValue(
        FakeIngredientRepository(),
      ),
      mealMediaRepositoryProvider.overrideWithValue(FakeMealMediaRepository()),
      currentUserIdProvider.overrideWithValue('user-1'),
    ];

    testWidgets('back with unsaved changes shows the discard dialog', (
      tester,
    ) async {
      final meal = _seededMeal();
      await _pumpEditScreen(
        tester,
        mealId: 'meal-42',
        overrides: defaultOverrides(meal),
      );

      // Dirty the state without touching the title controller (title is only
      // synced at save-time), so isDirty flips to true.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MealTrackerScreen)),
        listen: false,
      );
      container.read(mealTrackerProvider.notifier).addIngredient('Speck');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Änderungen verwerfen?'), findsOneWidget);
      expect(find.text('Deine Änderungen gehen verloren.'), findsOneWidget);
      expect(find.text('Weiter bearbeiten'), findsOneWidget);
      expect(find.text('Verwerfen'), findsOneWidget);
      // Screen still present behind the dialog.
      expect(find.byType(MealTrackerScreen), findsOneWidget);
    });

    testWidgets(
      'tapping "Weiter bearbeiten" closes the dialog and stays on the screen',
      (tester) async {
        final meal = _seededMeal();
        await _pumpEditScreen(
          tester,
          mealId: 'meal-42',
          overrides: defaultOverrides(meal),
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MealTrackerScreen)),
          listen: false,
        );
        container.read(mealTrackerProvider.notifier).addIngredient('Speck');
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Weiter bearbeiten'));
        await tester.pumpAndSettle();

        expect(find.text('Änderungen verwerfen?'), findsNothing);
        expect(find.byType(MealTrackerScreen), findsOneWidget);
        expect(find.text('home-sentinel'), findsNothing);
      },
    );

    testWidgets('tapping "Verwerfen" pops the screen', (tester) async {
      final meal = _seededMeal();
      await _pumpEditScreen(
        tester,
        mealId: 'meal-42',
        overrides: defaultOverrides(meal),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MealTrackerScreen)),
        listen: false,
      );
      container.read(mealTrackerProvider.notifier).addIngredient('Speck');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verwerfen'));
      await tester.pumpAndSettle();

      expect(find.text('Änderungen verwerfen?'), findsNothing);
      expect(find.byType(MealTrackerScreen), findsNothing);
      expect(find.text('home-sentinel'), findsOneWidget);
    });

    testWidgets('back with no unsaved changes pops silently', (tester) async {
      final meal = _seededMeal();
      await _pumpEditScreen(
        tester,
        mealId: 'meal-42',
        overrides: defaultOverrides(meal),
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Änderungen verwerfen?'), findsNothing);
      expect(find.byType(MealTrackerScreen), findsNothing);
      expect(find.text('home-sentinel'), findsOneWidget);
    });
  });
}
