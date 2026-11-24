// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:url_launcher/url_launcher.dart';

import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/models/knowledge_article.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/models/recommendation_item.dart';
import 'package:belly_buddy/models/replacement_ingredient.dart';
import 'package:belly_buddy/models/user_recipe.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/screens/discover/widgets/discover_tips_section.dart';
import 'package:belly_buddy/screens/discover/widgets/example_tip_card.dart';
import 'package:belly_buddy/widgets/common/weekly_tips_switch.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/discover_news_provider.dart';
import 'package:belly_buddy/providers/ingredient_suggestion_provider.dart';
import 'package:belly_buddy/providers/recommendation_provider.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/knowledge_repository.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';
import 'package:belly_buddy/screens/discover/widgets/knowledge_article_tile.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/discover/discover_screen.dart';
import 'package:belly_buddy/screens/recipes/recipes_screen.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_card.dart';

import '../../helpers/app_host.dart';
import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';
import '../../helpers/riverpod_helpers.dart';
import '../../helpers/widget_tester_helpers.dart';

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

void main() {
  late FakeProfileRepository profileRepo;
  late MockRecommendationRepository recommendations;
  late MockIngredientRepository ingredients;
  late MockUserRecipeRepository recipes;
  late RecordingUrlOpener launches;
  late FakeKnowledgeRepository knowledge;

  setUp(() {
    recommendations = MockRecommendationRepository();
    ingredients = MockIngredientRepository();
    recipes = MockUserRecipeRepository();
    launches = RecordingUrlOpener();
    knowledge = FakeKnowledgeRepository();
    profileRepo = FakeProfileRepository();
  });

  Future<void> pump(
    WidgetTester tester, {
    List<Recommendation> tips = const [],
    List<IngredientSuggestionGroup> groups = const [],
    List<UserRecipe> myRecipes = const [],
    double textScale = 1,
    bool realRecipesScreen = false,
    // null: the profile is still unknown.
    bool? weeklyTips,
    // Whether the app root keeps the news loaded, as in the app.
    bool appRoot = false,
  }) async {
    when(
      () => recommendations.fetchByUserId(any()),
    ).thenAnswer((_) async => tips);
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
          RoutePaths.knowledge,
        ]),
      ],
    );
    addTearDown(router.dispose);

    final List<Override> overrides = [
      currentUserIdProvider.overrideWithValue(testUserId),
      recommendationRepositoryProvider.overrideWithValue(recommendations),
      ingredientRepositoryProvider.overrideWithValue(ingredients),
      userRecipeRepositoryProvider.overrideWithValue(recipes),
      knowledgeRepositoryProvider.overrideWithValue(knowledge),
      profileRepositoryProvider.overrideWithValue(profileRepo),
      if (weeklyTips != null)
        profileProviderSeededWith(
          testUserProfile(weeklyTipsEnabled: weeklyTips),
        ),
    ];
    final app = germanRouterApp(router, textScale: textScale);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: appRoot
            ? Consumer(
                builder: (_, ref, child) {
                  ref.watch(discoverNewsProvider);
                  return child!;
                },
                child: app,
              )
            : app,
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inSection(Key section, Finder matching) =>
      find.descendant(of: find.byKey(section), matching: matching);

  group('weekly tips opt-in', () {
    final optIn = find.byKey(DiscoverTipsSection.optInKey);
    final someTips = [
      testRecommendation(
        id: 'new',
        recommendations: const [_item],
        createdAt: DateTime.utc(2026, 11, 16, 10),
      ),
    ];

    testWidgets('off, no tips: only the opt-in', (tester) async {
      await pump(tester, weeklyTips: false);

      expect(optIn, findsOneWidget);
      expect(find.text('Noch keine Tipps.'), findsNothing);
      expect(find.byKey(DiscoverScreen.tipsKey), findsNothing);
    });

    testWidgets('off, with tips: set card and opt-in', (tester) async {
      await pump(tester, weeklyTips: false, tips: someTips);

      expect(find.byKey(DiscoverScreen.tipsKey), findsOneWidget);
      expect(optIn, findsOneWidget);
    });

    testWidgets('weekly tips off: the example above the switch', (
      tester,
    ) async {
      await pump(tester, weeklyTips: false);

      final example = find.byKey(ExampleTipCard.cardKey);
      expect(example, findsOneWidget);
      expect(
        tester.getBottomLeft(example).dy,
        lessThan(tester.getTopLeft(optIn).dy),
      );
    });

    testWidgets('on: no example', (tester) async {
      await pump(tester, weeklyTips: true);

      expect(find.byKey(ExampleTipCard.cardKey), findsNothing);
    });

    testWidgets('on, no tips: when the first tips come', (tester) async {
      await pump(tester, weeklyTips: true);

      expect(find.text(DiscoverTipsSection.emptyWhileOn), findsOneWidget);
      expect(find.byKey(WeeklyTipsSwitch.switchKey), findsNothing);
    });

    testWidgets('on, with tips: no switch', (tester) async {
      await pump(tester, weeklyTips: true, tips: someTips);

      expect(find.byKey(DiscoverScreen.tipsKey), findsOneWidget);
      expect(find.byKey(WeeklyTipsSwitch.switchKey), findsNothing);
    });

    testWidgets('profile unknown: no switch', (tester) async {
      await pump(tester);

      expect(find.byKey(WeeklyTipsSwitch.switchKey), findsNothing);
      expect(find.text('Noch keine Tipps.'), findsOneWidget);
    });

    testWidgets('turning it on shows when the first tips come', (tester) async {
      profileRepo.seedProfile(testUserProfile());
      await pump(tester, weeklyTips: false);

      await tester.tapVisible(find.byKey(WeeklyTipsSwitch.switchKey));

      expect(profileRepo.weeklyTipsWrites, [true]);
      expect(find.text(DiscoverTipsSection.emptyWhileOn), findsOneWidget);
      expect(find.byKey(WeeklyTipsSwitch.switchKey), findsNothing);
    });
  });

  testWidgets('loads tips, alternatives and recipes when opened', (
    tester,
  ) async {
    await pump(tester);

    verify(() => recommendations.fetchByUserId(testUserId)).called(1);
    verify(() => ingredients.fetchSuggestionGroups(testUserId)).called(1);
    verify(() => recipes.fetchForUser(testUserId)).called(1);
    // Only the Tipps screen marks tips as seen.
    verifyNever(() => recommendations.markSeen(any(), any()));
  });

  testWidgets('opened right after sign-in: the tips and Alternativen load '
      'once, with the app root\'s sign-in load', (tester) async {
    await pump(tester, appRoot: true);

    verify(() => recommendations.fetchByUserId(testUserId)).called(1);
    verify(() => ingredients.fetchSuggestionGroups(testUserId)).called(1);
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

  testWidgets('Tipps card shows the newest set, „Neu" while unseen', (
    tester,
  ) async {
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
          seenAt: DateTime.utc(2026, 11, 10, 7),
        ),
      ],
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

    await tester.tapVisible(card);
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
          seenAt: DateTime.utc(2026, 11, 16, 18),
        ),
      ],
    );

    expect(inSection(DiscoverScreen.tipsKey, find.text('Neu')), findsNothing);
    expect(find.text('1 Tipp'), findsOneWidget);
  });

  testWidgets('„Neu" goes once the Tipps are marked seen, while Entdecken '
      'stays open underneath', (tester) async {
    when(() => recommendations.markSeen(any(), any())).thenAnswer((_) async {});
    await pump(
      tester,
      tips: [
        testRecommendation(
          recommendations: const [_item],
          createdAt: DateTime.utc(2026, 11, 16, 10),
        ),
      ],
    );
    expect(inSection(DiscoverScreen.tipsKey, find.text('Neu')), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiscoverScreen)),
    );
    await container.read(recommendationProvider.notifier).markAllAsSeen();
    await tester.pump();

    expect(inSection(DiscoverScreen.tipsKey, find.text('Neu')), findsNothing);
  });

  testWidgets('a tips push brings the new set to the card, as „Neu"', (
    tester,
  ) async {
    final lastWeek = testRecommendation(
      id: 'old',
      summary: 'Ältere Tipps.',
      recommendations: const [_item],
      createdAt: DateTime.utc(2026, 11, 9, 10),
      seenAt: DateTime.utc(2026, 11, 10, 7),
    );
    await pump(tester, tips: [lastWeek]);
    expect(find.text('Woche 46'), findsOneWidget);
    expect(inSection(DiscoverScreen.tipsKey, find.text('Neu')), findsNothing);

    // A new set arrives; the push handler refreshes the news.
    when(() => recommendations.fetchByUserId(any())).thenAnswer(
      (_) async => [
        testRecommendation(
          id: 'new',
          summary: 'Diese Woche lief es mit Reis besonders gut.',
          recommendations: const [_item, _item],
          createdAt: DateTime.utc(2026, 11, 16, 10),
        ),
        lastWeek,
      ],
    );
    await ProviderScope.containerOf(
      tester.element(find.byType(DiscoverScreen)),
    ).read(discoverNewsProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(inSection(DiscoverScreen.tipsKey, find.text('Neu')), findsOneWidget);
    expect(find.text('Woche 47'), findsOneWidget);
    expect(find.text('2 Tipps'), findsOneWidget);
    expect(find.text('Woche 46'), findsNothing);
  });

  testWidgets('a failed refresh (offline resume) keeps the set card and the '
      'Alternativen', (tester) async {
    await pump(
      tester,
      tips: [
        testRecommendation(
          recommendations: const [_item, _item],
          createdAt: DateTime.utc(2026, 11, 16, 10),
        ),
      ],
      groups: [
        _group('Zwiebel', isNew: true, lastMeal: DateTime(2026, 11, 20)),
      ],
    );

    when(
      () => recommendations.fetchByUserId(any()),
    ).thenAnswer((_) => Future.error(Exception('offline')));
    when(
      () => ingredients.fetchSuggestionGroups(any()),
    ).thenAnswer((_) => Future.error(Exception('offline')));
    await ProviderScope.containerOf(
      tester.element(find.byType(DiscoverScreen)),
    ).read(discoverNewsProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(find.textContaining('konnten nicht geladen werden'), findsNothing);
    expect(inSection(DiscoverScreen.tipsKey, find.text('Neu')), findsOneWidget);
    expect(find.text('Woche 47'), findsOneWidget);
    expect(find.text('Zwiebel'), findsOneWidget);
    expect(
      inSection(DiscoverScreen.alternativesKey, find.text('1 neu')),
      findsOneWidget,
    );
  });

  testWidgets('no tips', (tester) async {
    await pump(tester);

    expect(find.text('Noch keine Tipps.'), findsOneWidget);
    await tester.tapVisible(find.byKey(DiscoverScreen.tipsKey));
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

    await tester.tapVisible(
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

    await tester.tapVisible(
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

    await tester.tapVisible(
      inSection(DiscoverScreen.recipesKey, find.text('Alle ›')),
    );
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Keine Treffer'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
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

    await tester.tapVisible(
      inSection(DiscoverScreen.recipesKey, find.byIcon(Icons.add)),
    );
    expect(find.text('Rezept hinzufügen'), findsOneWidget);
  });

  testWidgets('a recipe card opens that recipe', (tester) async {
    await pump(tester, myRecipes: [testUserRecipe(id: 'r1')]);

    await tester.tapVisible(find.byType(RecipeCard));
    expect(find.text('page:${RoutePaths.recipeDetail}'), findsOneWidget);
  });

  testWidgets('no recipes', (tester) async {
    await pump(tester);

    expect(find.text('Noch keine Rezepte.'), findsOneWidget);
    expect(
      inSection(DiscoverScreen.recipesKey, find.text('Alle ›')),
      findsNothing,
    );
    await tester.tapVisible(find.text('Erstes Rezept erstellen'));
    expect(find.text('Rezept hinzufügen'), findsOneWidget);
  });

  Finder tilesIn(Key section) =>
      inSection(section, find.byType(KnowledgeArticleTile));

  testWidgets('Wissen previews the newest 3 and Alle ›', (tester) async {
    await pump(tester);

    expect(tilesIn(DiscoverScreen.knowledgeKey), findsNWidgets(3));
    for (final t in [
      'Was ist FODMAP?',
      'Suppe für kalte Tage',
      'Mein Weg zum Bauchgefühl',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Ballaststoffe verstehen'), findsNothing);

    await tester.tapVisible(
      inSection(DiscoverScreen.knowledgeKey, find.text('Alle ›')),
    );
    expect(find.text('page:${RoutePaths.knowledge}'), findsOneWidget);
  });

  testWidgets('a fresh copy of the articles: opening fetches none', (
    tester,
  ) async {
    knowledge = FakeKnowledgeRepository(
      cache: KnowledgeFeed(
        articles: testKnowledgeArticles(),
        fetchedAt: DateTime.now(),
      ),
    );
    await pump(tester);

    expect(knowledge.fetchCount, 0);
    expect(tilesIn(DiscoverScreen.knowledgeKey), findsNWidgets(3));
  });

  testWidgets('an article opens in the in-app browser', (tester) async {
    await pump(tester);

    await tester.tapVisible(
      find.byKey(KnowledgeArticleTile.keyFor(knowledge.articles.first)),
    );

    expect(launches.urls, [knowledge.articles.first.link]);
    expect(launches.modes, [LaunchMode.inAppBrowserView]);
  });

  testWidgets('no copy and offline', (tester) async {
    knowledge.fetchError = Exception('offline');
    await pump(tester);

    expect(find.text('Artikel konnten nicht geladen werden.'), findsOneWidget);
    expect(
      inSection(DiscoverScreen.knowledgeKey, find.text('Alle ›')),
      findsNothing,
    );
  });

  testWidgets('no articles', (tester) async {
    knowledge = FakeKnowledgeRepository(articles: const []);
    await pump(tester);

    expect(find.text('Gerade keine Artikel.'), findsOneWidget);
    expect(
      inSection(DiscoverScreen.knowledgeKey, find.text('Alle ›')),
      findsNothing,
    );
  });

  testWidgets('pull to refresh reloads all four', (tester) async {
    await pump(tester);
    final feedFetches = knowledge.fetchCount;

    await tester.fling(
      find.byType(RefreshIndicator),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    verify(() => recommendations.fetchByUserId(testUserId)).called(2);
    verify(() => ingredients.fetchSuggestionGroups(testUserId)).called(2);
    verify(() => recipes.fetchForUser(testUserId)).called(2);
    expect(knowledge.fetchCount, feedFetches + 1);
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
    await tester.drag(find.byType(RefreshIndicator), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(DiscoverScreen.knowledgeKey), findsOneWidget);
  });
}
