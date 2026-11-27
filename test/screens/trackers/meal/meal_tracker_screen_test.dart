// ignore_for_file: invalid_use_of_internal_member
import 'package:belly_buddy/models/ingredient_suggestion_group.dart' as model;
import 'package:belly_buddy/models/meal_entry.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:belly_buddy/models/meal_prefill.dart';
import 'package:belly_buddy/models/product.dart';
import 'package:belly_buddy/services/product_service.dart';
import 'package:belly_buddy/widgets/scanner/barcode_scanner.dart';
import 'package:belly_buddy/screens/trackers/meal/widgets/product_finder_sheet.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/screens/trackers/meal/widgets/meal_image_section.dart';
import 'package:belly_buddy/widgets/common/ingredient_search.dart';
import 'package:belly_buddy/providers/buddy_events_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/ingredient_suggestion_provider.dart';
import 'package:belly_buddy/providers/meal_tracker_provider.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/trackers/meal/meal_tracker_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/src/internals.dart' show Override;

import '../../../helpers/app_host.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/riverpod_helpers.dart';

/// Builds a 2-route GoRouter so the tracker screen (reached via /edit) can
/// `context.pop()` back to a sentinel home screen. This lets tests assert on
/// the pop behaviour without mocking the navigator directly.
GoRouter _buildRouter(String? mealId, {MealPrefill? recipe}) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('home-sentinel')),
      ),
      GoRoute(
        path: '/edit',
        builder: (_, _) =>
            MealTrackerScreen(mealId: mealId, initialRecipe: recipe),
      ),
    ],
  );
}

Future<void> _pumpEditScreen(
  WidgetTester tester, {
  required String? mealId,
  required List<Override> overrides,
  MealPrefill? recipe,
}) async {
  final router = _buildRouter(mealId, recipe: recipe);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: ProviderContainer.test(overrides: overrides),
      child: germanRouterApp(router),
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

const _barcode = '4000000000013';

const _product = ProductPrefill(
  barcode: _barcode,
  title: 'Testjoghurt',
  brand: 'Testmarke',
  ingredients: [
    ProductIngredient(name: 'Milch', ingredientId: 'i-1'),
    ProductIngredient(name: 'Zucker'),
  ],
);

class _FoundProductService implements ProductService {
  @override
  Future<ProductLookup> lookup(String barcode) async => ProductFound(_product);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _scannerStub(
  BuildContext context, {
  required bool active,
  required ValueChanged<String> onBarcode,
  required ValueChanged<ScannerFailure> onFailure,
}) => ElevatedButton(
  onPressed: () => onBarcode(_barcode),
  child: const Text('emit'),
);

class _HangingMediaRepository extends FakeMealMediaRepository {
  final answer = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> analyzeMealImage(
    Uint8List bytes,
    String filename,
  ) => answer.future;
}

List<Override> _productOverrides({
  List<MealEntry> meals = const [],
  FakeEntryRepository? entries,
  FakeMealMediaRepository? media,
}) => [
  entriesProviderSeededWith(meals),
  entryRepositoryProvider.overrideWithValue(entries ?? FakeEntryRepository()),
  ingredientRepositoryProvider.overrideWithValue(FakeIngredientRepository()),
  mealMediaRepositoryProvider.overrideWithValue(
    media ?? FakeMealMediaRepository(),
  ),
  currentUserIdProvider.overrideWithValue('user-1'),
  productServiceProvider.overrideWithValue(_FoundProductService()),
  barcodeScannerProvider.overrideWithValue(_scannerStub),
];

Future<void> _scanAndTake(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(MealTrackerScreen.productButtonKey));
  await tester.tap(find.byKey(MealTrackerScreen.productButtonKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text('emit'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ProductFinderSheet.applyKey));
  await tester.pumpAndSettle();
}

void _productTests() {
  group('MealTrackerScreen product button', () {
    for (final edit in [false, true]) {
      testWidgets(
        'sits between the photo area and the ingredients (${edit ? 'edit' : 'create'})',
        (tester) async {
          await _pumpEditScreen(
            tester,
            mealId: edit ? 'meal-42' : null,
            overrides: _productOverrides(meals: [_seededMeal()]),
          );
          final button = find.byKey(MealTrackerScreen.productButtonKey);
          expect(button, findsOneWidget);
          expect(find.text('Barcode scannen oder suchen'), findsOneWidget);
          final y = tester.getTopLeft(button).dy;
          expect(
            tester.getTopLeft(find.byType(MealImageSection)).dy,
            lessThan(y),
          );
          expect(
            tester.getTopLeft(find.byType(IngredientSearch)).dy,
            greaterThan(y),
          );
        },
      );
    }

    testWidgets('a product fills title and chips; Speichern saves a normal '
        'meal', (tester) async {
      tester.view
        ..physicalSize = const Size(1170, 2532)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final entries = FakeEntryRepository();
      await _pumpEditScreen(
        tester,
        mealId: null,
        overrides: _productOverrides(entries: entries),
      );
      await _scanAndTake(tester);
      expect(find.text('Milch'), findsOneWidget);
      expect(find.text('Zucker'), findsOneWidget);
      expect(find.text('Testjoghurt'), findsWidgets);

      await tester.ensureVisible(find.byKey(MealTrackerScreen.mealEditSaveKey));
      await tester.tap(find.byKey(MealTrackerScreen.mealEditSaveKey));
      await tester.pumpAndSettle();
      expect(entries.addedMeals, hasLength(1));
      final saved = entries.addedMeals.single;
      expect(saved.title, 'Testjoghurt');
      expect(saved.ingredients, ['Milch', 'Zucker']);
      expect(saved.imageUrl, isNull);
    });

    testWidgets('dismissing the sheet changes nothing', (tester) async {
      tester.view
        ..physicalSize = const Size(1170, 2532)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await _pumpEditScreen(
        tester,
        mealId: null,
        overrides: _productOverrides(),
      );
      await tester.tap(find.byKey(MealTrackerScreen.productButtonKey));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MealTrackerScreen)),
        listen: false,
      );
      final state = container.read(mealTrackerProvider);
      expect(state.ingredients, isEmpty);
      expect(state.title, kDefaultMealTitle);
    });

    testWidgets('disabled while a photo is analysed', (tester) async {
      final media = _HangingMediaRepository();
      await _pumpEditScreen(
        tester,
        mealId: null,
        overrides: _productOverrides(media: media),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MealTrackerScreen)),
        listen: false,
      );
      final analysis = container
          .read(mealTrackerProvider.notifier)
          .analyzeImage(Uint8List(1), 'a.jpg');
      await tester.pump();
      final button = tester.widget<OutlinedButton>(
        find.byKey(MealTrackerScreen.productButtonKey),
      );
      expect(button.onPressed, isNull);
      media.answer.complete({'title': 'X', 'ingredients': <String>[]});
      await analysis;
      await tester.pump();
    });
  });
}

void main() {
  _productTests();
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
        // Edits are not new logs: the Buddy does not react.
        expect(container.read(buddyEventsProvider), isNull);
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

  group('MealTrackerScreen new meal', () {
    List<Override> overrides() => [
      entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
      ingredientRepositoryProvider.overrideWithValue(
        FakeIngredientRepository(),
      ),
      mealMediaRepositoryProvider.overrideWithValue(FakeMealMediaRepository()),
      userRecipeRepositoryProvider.overrideWithValue(
        FakeUserRecipeRepository(),
      ),
      currentUserIdProvider.overrideWithValue('user-1'),
    ];

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.byType(MealTrackerScreen)),
          listen: false,
        );

    testWidgets('back with an ingredient added asks before discarding', (
      tester,
    ) async {
      await _pumpEditScreen(tester, mealId: null, overrides: overrides());
      containerOf(
        tester,
      ).read(mealTrackerProvider.notifier).addIngredient('Haferflocken');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Änderungen verwerfen?'), findsOneWidget);
      await tester.tap(find.text('Verwerfen'));
      await tester.pumpAndSettle();
      expect(find.text('home-sentinel'), findsOneWidget);
    });

    testWidgets('back from an empty new meal leaves silently', (tester) async {
      await _pumpEditScreen(tester, mealId: null, overrides: overrides());

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Änderungen verwerfen?'), findsNothing);
      expect(find.text('home-sentinel'), findsOneWidget);
    });

    testWidgets('back from an unchanged meal started from a recipe leaves '
        'silently', (tester) async {
      await _pumpEditScreen(
        tester,
        mealId: null,
        overrides: overrides(),
        recipe: const MealPrefill(title: 'Porridge', ingredients: ['Hafer']),
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Änderungen verwerfen?'), findsNothing);
      expect(find.text('home-sentinel'), findsOneWidget);
    });

    testWidgets('a meal started from a recipe and then changed asks', (
      tester,
    ) async {
      await _pumpEditScreen(
        tester,
        mealId: null,
        overrides: overrides(),
        recipe: const MealPrefill(title: 'Porridge', ingredients: ['Hafer']),
      );
      containerOf(
        tester,
      ).read(mealTrackerProvider.notifier).addIngredient('Banane');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Änderungen verwerfen?'), findsOneWidget);
    });
  });

  group('MealTrackerScreen success screen: flagged ingredients', () {
    model.IngredientSuggestionGroup groupFor(String name, String mealId) =>
        testSuggestionGroup(
          ingredientId: 'ing-$name',
          ingredientName: name,
        ).copyWith(
          meals: [
            model.MealDetail(
              id: mealId,
              title: 'Bowl',
              trackedAt: DateTime(2026, 11, 27, 12),
            ),
          ],
        );

    Future<ProviderContainer> pumpSuccess(
      WidgetTester tester,
      List<model.IngredientSuggestionGroup> groups,
    ) async {
      final container = ProviderContainer.test(
        overrides: [
          entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
          ingredientRepositoryProvider.overrideWithValue(
            FakeIngredientRepository(groups: groups),
          ),
          mealMediaRepositoryProvider.overrideWithValue(
            FakeMealMediaRepository(),
          ),
          buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
          userRecipeRepositoryProvider.overrideWithValue(
            FakeUserRecipeRepository(),
          ),
          currentUserIdProvider.overrideWithValue('user-1'),
        ],
      );
      final router = GoRouter(
        initialLocation: '/meal-tracker',
        routes: [
          GoRoute(
            path: '/meal-tracker',
            builder: (_, _) => const MealTrackerScreen(),
          ),
          GoRoute(
            path: RoutePaths.ingredientSuggestions,
            builder: (_, _) =>
                const Scaffold(body: Text('alternatives-sentinel')),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: germanRouterApp(router),
        ),
      );
      await tester.pumpAndSettle();
      container
          .read(mealTrackerProvider.notifier)
          .markShowSuccess(savedMealId: 'meal-1');
      // The success screen's Buddy animates forever: no pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      return container;
    }

    testWidgets('success screen: groups for the meal arrive while it is up '
        '→ the line and the link appear', (tester) async {
      final container = await pumpSuccess(tester, [
        groupFor('Zwiebel', 'meal-1'),
        groupFor('Knoblauch', 'meal-1'),
        groupFor('Lauch', 'other-meal'),
      ]);
      const line =
          'Knoblauch und Zwiebel könnten deinem Bauch zu schaffen machen.';
      expect(find.text(line), findsNothing);

      await container
          .read(ingredientSuggestionProvider.notifier)
          .fetchSuggestions();
      await tester.pump();

      expect(find.text(line), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(line)).dy,
        lessThan(tester.getTopLeft(find.text('Trinken eintragen')).dy),
      );

      await tester.tap(find.text('Alternativen ansehen ›'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('alternatives-sentinel'), findsOneWidget);
    });

    testWidgets('success screen: no groups → no line, no placeholder', (
      tester,
    ) async {
      final container = await pumpSuccess(tester, [
        groupFor('Lauch', 'other-meal'),
      ]);
      await container
          .read(ingredientSuggestionProvider.notifier)
          .fetchSuggestions();
      await tester.pump();

      expect(find.textContaining('zu schaffen machen'), findsNothing);
      expect(find.text('Alternativen ansehen ›'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Trinken eintragen'), findsOneWidget);
    });
  });
}
