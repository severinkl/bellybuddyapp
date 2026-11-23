// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:url_launcher/url_launcher.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/models/recommendation_item.dart';
import 'package:belly_buddy/models/replacement_ingredient.dart';
import 'package:belly_buddy/models/user_recipe.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/ingredient_suggestion_provider.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/discover/discover_screen.dart';
import 'package:belly_buddy/screens/recipes/recipes_screen.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_card.dart';

import '../../helpers/app_host.dart';
import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

const _item = RecommendationItem(
  type: 'try',
  ingredient: 'Haferflocken',
  reason: 'Gut verträglich.',
);

IngredientSuggestionGroup _group(
  String name, {
  bool isNew = false,
  DateTime? lastMeal,
}) => IngredientSuggestionGroup(
  ingredientId: 'ing-$name',
  ingredientName: name,
  mealCount: 1,
  isNew: isNew,
  suggestionIds: ['sug-$name'],
  meals: [
    if (lastMeal != null)
      MealDetail(id: 'meal-$name', title: 'Essen', trackedAt: lastMeal),
  ],
);

/// The launched URL and mode, from [DiscoverScreen.openUrl].
class _Launches {
  final urls = <Uri>[];
  final modes = <LaunchMode>[];
  bool result = true;

  Future<bool> call(Uri url, {LaunchMode mode = LaunchMode.platformDefault}) {
    urls.add(url);
    modes.add(mode);
    return Future.value(result);
  }
}

void main() {
  late MockRecommendationRepository recommendations;
  late MockIngredientRepository ingredients;
  late MockUserRecipeRepository recipes;
  late _Launches launches;

  setUp(() {
    recommendations = MockRecommendationRepository();
    ingredients = MockIngredientRepository();
    recipes = MockUserRecipeRepository();
    launches = _Launches();
  });

  Future<void> pump(
    WidgetTester tester, {
    List<Recommendation> tips = const [],
    int unseenTips = 0,
    List<IngredientSuggestionGroup> groups = const [],
    List<UserRecipe> myRecipes = const [],
    double textScale = 1,
    bool realRecipesScreen = false,
  }) async {
    when(
      () => recommendations.fetchByUserId(any()),
    ).thenAnswer((_) async => tips);
    when(
      () => recommendations.countUnseen(any()),
    ).thenAnswer((_) async => unseenTips);
    when(
      () => ingredients.fetchSuggestionGroups(any()),
    ).thenAnswer((_) async => groups);
    when(() => recipes.fetchForUser(any())).thenAnswer((_) async => myRecipes);
    when(
      () => recipes.searchForUser(any(), any()),
    ).thenAnswer((_) async => const []);

    final router = GoRouter(
      initialLocation: RoutePaths.discover,
      routes: [
        GoRoute(
          path: RoutePaths.discover,
          builder: (_, _) => DiscoverScreen(openUrl: launches.call),
        ),
        if (realRecipesScreen)
          GoRoute(
            path: RoutePaths.recipes,
            builder: (_, _) => const RecipesScreen(),
          ),
        ...stubRoutes([
          RoutePaths.recommendations,
          RoutePaths.ingredientSuggestions,
          if (!realRecipesScreen) RoutePaths.recipes,
          RoutePaths.recipeDetail,
        ]),
      ],
    );
    addTearDown(router.dispose);

    final List<Override> overrides = [
      currentUserIdProvider.overrideWithValue(testUserId),
      recommendationRepositoryProvider.overrideWithValue(recommendations),
      ingredientRepositoryProvider.overrideWithValue(ingredients),
      userRecipeRepositoryProvider.overrideWithValue(recipes),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: germanRouterApp(router, textScale: textScale),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inSection(Key section, Finder matching) =>
      find.descendant(of: find.byKey(section), matching: matching);

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('loads tips, alternatives and recipes when opened', (
    tester,
  ) async {
    await pump(tester);

    verify(() => recommendations.fetchByUserId(testUserId)).called(1);
    verify(() => ingredients.fetchSuggestionGroups(testUserId)).called(1);
    verify(() => recipes.fetchForUser(testUserId)).called(1);
    // Only the Tipps screen marks tips as seen.
    verifyNever(() => recommendations.markAllAsSeen(any()));
  });

  testWidgets('four sections in order', (tester) async {
    await pump(tester);

    final tops = [
      for (final title in ['Tipps', 'Alternativen', 'Meine Rezepte', 'Wissen'])
        tester.getTopLeft(find.text(title)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(tops.toSet(), hasLength(4));
  });

  testWidgets('Tipps card shows the newest set', (tester) async {
    await pump(
      tester,
      tips: [
        testRecommendation(
          id: 'new',
          summary: 'Diese Woche lief es mit Reis besonders gut.',
          recommendations: const [_item, _item, _item],
          createdAt: DateTime.utc(2026, 11, 16, 10),
        ),
        testRecommendation(
          id: 'old',
          summary: 'Ältere Tipps.',
          recommendations: const [_item],
          createdAt: DateTime.utc(2026, 11, 9, 10),
        ),
      ],
      unseenTips: 1,
    );

    final card = find.byKey(DiscoverScreen.tipsKey);
    expect(inSection(DiscoverScreen.tipsKey, find.text('Neu')), findsOneWidget);
    expect(find.text('Woche 47'), findsOneWidget);
    expect(find.text('3 Tipps'), findsOneWidget);
    expect(
      find.text('Diese Woche lief es mit Reis besonders gut.'),
      findsOneWidget,
    );
    expect(find.text('Woche 46'), findsNothing);
    expect(find.text('Ältere Tipps.'), findsNothing);

    await tapVisible(tester, card);
    expect(find.text('page:${RoutePaths.recommendations}'), findsOneWidget);
  });

  testWidgets('a seen set has no „Neu" and one tip reads „1 Tipp"', (
    tester,
  ) async {
    await pump(
      tester,
      tips: [
        testRecommendation(
          recommendations: const [_item],
          createdAt: DateTime.utc(2026, 11, 16, 10),
        ),
      ],
    );

    expect(inSection(DiscoverScreen.tipsKey, find.text('Neu')), findsNothing);
    expect(find.text('1 Tipp'), findsOneWidget);
  });

  testWidgets('no tips', (tester) async {
    await pump(tester);

    expect(find.text('Noch keine Tipps.'), findsOneWidget);
    await tapVisible(tester, find.byKey(DiscoverScreen.tipsKey));
    expect(find.text('page:${RoutePaths.recommendations}'), findsNothing);
    expect(find.byType(DiscoverScreen), findsOneWidget);
  });

  testWidgets('Alternativen previews the newest 3', (tester) async {
    await pump(
      tester,
      groups: [
        // Alphabetical, as the repository returns them.
        _group('Apfel', lastMeal: DateTime(2026, 11, 10)),
        _group('Bohnen', isNew: true, lastMeal: DateTime(2026, 11, 18)),
        _group('Knoblauch', lastMeal: DateTime(2026, 11, 22)),
        _group('Milch'),
        _group('Zwiebel', isNew: true, lastMeal: DateTime(2026, 11, 20)),
      ],
    );

    // New first, then by the latest meal.
    for (final name in ['Zwiebel', 'Bohnen', 'Knoblauch']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text('Apfel'), findsNothing);
    expect(find.text('Milch'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Zwiebel')).dy,
      lessThan(tester.getTopLeft(find.text('Bohnen')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Bohnen')).dy,
      lessThan(tester.getTopLeft(find.text('Knoblauch')).dy),
    );
    expect(
      inSection(DiscoverScreen.alternativesKey, find.text('2 neu')),
      findsOneWidget,
    );

    await tapVisible(
      tester,
      inSection(DiscoverScreen.alternativesKey, find.text('Alle ›')),
    );
    expect(
      find.text('page:${RoutePaths.ingredientSuggestions}'),
      findsOneWidget,
    );
  });

  testWidgets('„n neu" goes once the Alternativen are marked seen, while '
      'Entdecken stays open underneath', (tester) async {
    when(() => ingredients.markAllSeen(any())).thenAnswer((_) async {});
    await pump(
      tester,
      groups: [
        _group('Bohnen', isNew: true, lastMeal: DateTime(2026, 11, 18)),
        _group('Zwiebel', isNew: true, lastMeal: DateTime(2026, 11, 20)),
      ],
    );
    expect(
      inSection(DiscoverScreen.alternativesKey, find.text('2 neu')),
      findsOneWidget,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiscoverScreen)),
    );
    await container
        .read(ingredientSuggestionProvider.notifier)
        .markAllNewAsSeen();
    await tester.pump();

    expect(
      inSection(
        DiscoverScreen.alternativesKey,
        find.textContaining(RegExp(r'^\d+ neu$')),
      ),
      findsNothing,
    );
  });

  testWidgets('an alternative names what can replace it', (tester) async {
    await pump(
      tester,
      groups: [
        const IngredientSuggestionGroup(
          ingredientId: 'ing-1',
          ingredientName: 'Zwiebel',
          mealCount: 1,
          isNew: false,
          suggestionIds: ['sug-1'],
          replacements: [
            ReplacementIngredient(id: 'r1', name: 'Schnittlauch'),
            ReplacementIngredient(id: 'r2', name: 'Lauchgrün'),
          ],
        ),
      ],
    );

    expect(find.text('Stattdessen: Schnittlauch, Lauchgrün'), findsOneWidget);
    // Nothing unseen: no badge.
    expect(
      inSection(
        DiscoverScreen.alternativesKey,
        find.textContaining(RegExp(r'^\d+ neu$')),
      ),
      findsNothing,
    );
  });

  testWidgets('no alternatives: a line, no „Alle ›"', (tester) async {
    await pump(tester);

    expect(
      find.text(
        'Noch keine Alternativen – sie entstehen nach deinen Mahlzeiten.',
      ),
      findsOneWidget,
    );
    expect(
      inSection(DiscoverScreen.alternativesKey, find.text('Alle ›')),
      findsNothing,
    );
    expect(
      inSection(
        DiscoverScreen.alternativesKey,
        find.textContaining(RegExp(r'^\d+ neu$')),
      ),
      findsNothing,
    );
  });

  testWidgets('Meine Rezepte', (tester) async {
    await pump(
      tester,
      myRecipes: [
        for (var i = 1; i <= 8; i++)
          testUserRecipe(id: 'r$i', title: 'Rezept $i'),
      ],
    );

    expect(find.byType(RecipeCard), findsNWidgets(6));
    expect(find.text('Rezept 6'), findsOneWidget);
    expect(find.text('Rezept 7'), findsNothing);

    await tapVisible(
      tester,
      inSection(DiscoverScreen.recipesKey, find.text('Alle ›')),
    );
    expect(find.text('page:${RoutePaths.recipes}'), findsOneWidget);
  });

  testWidgets('a search on /recipes does not follow back to Entdecken', (
    tester,
  ) async {
    await pump(
      tester,
      realRecipesScreen: true,
      myRecipes: [
        testUserRecipe(id: 'r1', title: 'Curry mit Reis'),
        testUserRecipe(id: 'r2', title: 'Pasta Bolognese'),
      ],
    );

    await tapVisible(
      tester,
      inSection(DiscoverScreen.recipesKey, find.text('Alle ›')),
    );
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Keine Treffer'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    // The closed screen dropped the search; the reload is debounced.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(DiscoverScreen), findsOneWidget);
    expect(find.text('Noch keine Rezepte.'), findsNothing);
    expect(find.byType(RecipeCard), findsNWidgets(2));
    expect(
      inSection(DiscoverScreen.recipesKey, find.text('Alle ›')),
      findsOneWidget,
    );
  });

  testWidgets("Meine Rezepte's + opens the chooser", (tester) async {
    await pump(tester, myRecipes: [testUserRecipe()]);

    await tapVisible(
      tester,
      inSection(DiscoverScreen.recipesKey, find.byIcon(Icons.add)),
    );
    expect(find.text('Rezept hinzufügen'), findsOneWidget);
  });

  testWidgets('a recipe card opens that recipe', (tester) async {
    await pump(tester, myRecipes: [testUserRecipe(id: 'r1')]);

    await tapVisible(tester, find.byType(RecipeCard));
    expect(find.text('page:${RoutePaths.recipeDetail}'), findsOneWidget);
  });

  testWidgets('no recipes', (tester) async {
    await pump(tester);

    expect(find.text('Noch keine Rezepte.'), findsOneWidget);
    expect(
      inSection(DiscoverScreen.recipesKey, find.text('Alle ›')),
      findsNothing,
    );
    await tapVisible(tester, find.text('Erstes Rezept erstellen'));
    expect(find.text('Rezept hinzufügen'), findsOneWidget);
  });

  testWidgets('Wissen opens the blog', (tester) async {
    await pump(tester);

    expect(find.text('Wissen rund um die Verdauung'), findsOneWidget);
    expect(find.text('Artikel aus dem myfodmap-Blog'), findsOneWidget);
    await tapVisible(tester, find.byKey(DiscoverScreen.knowledgeKey));

    expect(launches.urls, [Uri.parse(AppConstants.blogUrl)]);
    expect(launches.modes, [LaunchMode.externalApplication]);
    expect(AppConstants.blogUrl, 'https://www.myfodmap.at/blog');
  });

  testWidgets('a blog that does not open says so', (tester) async {
    launches.result = false;
    await pump(tester);

    await tapVisible(tester, find.byKey(DiscoverScreen.knowledgeKey));
    expect(find.text('Der Blog konnte nicht geöffnet werden.'), findsOneWidget);
  });

  testWidgets('pull to refresh reloads all three', (tester) async {
    await pump(tester);

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    verify(() => recommendations.fetchByUserId(testUserId)).called(2);
    verify(() => recommendations.countUnseen(testUserId)).called(2);
    verify(() => ingredients.fetchSuggestionGroups(testUserId)).called(2);
    verify(() => recipes.fetchForUser(testUserId)).called(2);
  });

  testWidgets('fits a 375×667 phone at text scale 1.3', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pump(
      tester,
      textScale: 1.3,
      tips: [
        testRecommendation(
          summary:
              'Eine lange Zusammenfassung, die über mehrere Zeilen läuft und '
              'deshalb nach zwei Zeilen abgeschnitten wird, damit die Karte '
              'kompakt bleibt.',
          recommendations: const [_item, _item, _item],
          createdAt: DateTime.utc(2026, 11, 16, 10),
        ),
      ],
      unseenTips: 1,
      groups: [
        for (final name in ['Zwiebel', 'Knoblauch', 'Weizen'])
          _group(name, isNew: true, lastMeal: DateTime(2026, 11, 20)),
      ],
      myRecipes: [
        for (var i = 1; i <= 6; i++)
          testUserRecipe(
            id: 'r$i',
            title: 'Ein Rezept mit einem langen Namen $i',
          ),
      ],
    );

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(DiscoverScreen.knowledgeKey), findsOneWidget);
  });
}
