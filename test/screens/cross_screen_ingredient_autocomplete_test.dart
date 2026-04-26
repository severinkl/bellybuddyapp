// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/ingredient_search_result.dart';
import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/ingredient_autocomplete_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/screens/recipes/recipe_editor_screen.dart';
import 'package:belly_buddy/screens/trackers/meal/meal_tracker_screen.dart';
import 'package:belly_buddy/widgets/common/ingredient_search.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';

/// IngredientRepository fake that mimics the production "shared user
/// ingredients table" contract: `insertIfNew` records the name, and a
/// later `search` returns it as a case-insensitive substring match.
///
/// This is the only fake that lets us prove the cross-screen autocomplete
/// contract end-to-end — the shipped [FakeIngredientRepository] returns
/// a fixed echo of the query and doesn't model the table.
class _RecordingIngredientRepository implements IngredientRepository {
  final List<String> userIngredients = [];

  @override
  Future<List<IngredientSearchResult>> search(
    String query, {
    required String? userId,
    int limit = 10,
  }) async {
    final lowered = query.toLowerCase();
    return userIngredients
        .where((name) => name.toLowerCase().contains(lowered))
        .map(
          (name) => IngredientSearchResult(
            id: 'i-${name.hashCode}',
            name: name,
            isOwn: true,
          ),
        )
        .toList();
  }

  @override
  Future<void> insertIfNew(String name, {required String? userId}) async {
    if (!userIngredients.contains(name)) userIngredients.add(name);
  }

  @override
  Future<void> deleteUserIngredient(String id) async {
    userIngredients.removeWhere((name) => 'i-${name.hashCode}' == id);
  }

  @override
  Future<List<IngredientSuggestionGroup>> fetchSuggestionGroups(
    String userId,
  ) async => const [];

  @override
  Future<void> markAllSeen(List<String> ids) async {}

  @override
  Future<void> dismissSuggestions(List<String> ids) async {}

  @override
  Future<int> fetchNewCount(String userId) async => 0;
}

GoRouter _buildRouter() => GoRouter(
  initialLocation: '/recipe/new',
  routes: [
    GoRoute(path: '/recipe/new', builder: (_, _) => const RecipeEditorScreen()),
    GoRoute(
      path: '/meal-tracker',
      builder: (_, _) => const MealTrackerScreen(),
    ),
  ],
);

Future<({GoRouter router, ProviderContainer container})> _pumpApp(
  WidgetTester tester, {
  required _RecordingIngredientRepository ingredientRepo,
}) async {
  // Tall viewport so the SingleChildScrollView's IngredientSearch row is
  // not pushed below the fold by MealImageSection above it.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final mockUserRecipeRepo = MockUserRecipeRepository();
  when(
    () => mockUserRecipeRepo.fetchForUser(any()),
  ).thenAnswer((_) async => []);

  final router = _buildRouter();
  final container = ProviderContainer.test(
    overrides: [
      ingredientRepositoryProvider.overrideWithValue(ingredientRepo),
      userRecipeRepositoryProvider.overrideWithValue(mockUserRecipeRepo),
      mealMediaRepositoryProvider.overrideWithValue(FakeMealMediaRepository()),
      entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
      entriesProviderSeededWith(const []),
      currentUserIdProvider.overrideWithValue(testUserId),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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
  await tester.pumpAndSettle();
  return (router: router, container: container);
}

void main() {
  testWidgets(
    'ingredient added in the recipe editor surfaces as an autocomplete '
    'suggestion when typing in the meal tracker',
    (tester) async {
      final fakeRepo = _RecordingIngredientRepository();
      final app = await _pumpApp(tester, ingredientRepo: fakeRepo);

      // Phase 1: recipe editor is mounted. Add "Fenchel" via the shared
      // ingredientAutocompleteProvider directly — exercising the API the
      // editor's IngredientSearch wires to under the hood. (The widget's
      // own UI flow has a scroll-into-view post-frame timer that races
      // teardown when navigating routes mid-test; the contract being
      // verified — "add in one screen, search in another" — doesn't
      // depend on the typing UX.)
      expect(find.byType(RecipeEditorScreen), findsOneWidget);
      await app.container
          .read(ingredientAutocompleteProvider.notifier)
          .addIngredient('Fenchel');
      await tester.pump();

      expect(
        fakeRepo.userIngredients,
        contains('Fenchel'),
        reason:
            'shared autocomplete provider wrote the ingredient via '
            'insertIfNew',
      );

      // Phase 2: navigate to the meal tracker. router.go replaces the
      // route stack, so only the meal tracker remains in the tree.
      app.router.go('/meal-tracker');
      await tester.pumpAndSettle();
      expect(find.byType(MealTrackerScreen), findsOneWidget);

      // Phase 3: type a 3-char prefix in the meal tracker's
      // IngredientSearch field. The shared autocomplete provider's
      // searchIngredients calls fake.search, which returns matches by
      // case-insensitive substring against the recorded user list.
      await tester.tap(find.text('+ Hinzufügen'));
      await tester.pumpAndSettle();

      final mealField = find.descendant(
        of: find.byType(IngredientSearch),
        matching: find.byType(TextField),
      );
      await tester.enterText(mealField, 'Fen');
      // Drain the IngredientSearch onSearch debounce (300 ms) before asserting.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Suggestions render as ListTile rows under the search field. The
      // ingredient added in the previous screen is now offered as an
      // autocomplete suggestion — the contract the shared provider exists
      // to deliver.
      expect(
        find.widgetWithText(ListTile, 'Fenchel'),
        findsOneWidget,
        reason:
            'shared autocomplete provider returns the ingredient '
            'recorded by the recipe editor',
      );
    },
  );
}
