import 'dart:async';
import 'dart:io' show SocketException;

// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:url_launcher/url_launcher.dart';

import 'package:belly_buddy/models/alternative_choice.dart';
import 'package:belly_buddy/models/ranked_replacement.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/models/fodmap_flags.dart';
import 'package:belly_buddy/models/knowledge_article.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/screens/recipes/widgets/fit_badge_view.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_collection_card.dart';
import 'package:belly_buddy/services/recipes/recipe_copy.dart';
import 'package:belly_buddy/models/dietitian_tip.dart';
import 'package:belly_buddy/models/recommendation.dart';
import 'package:belly_buddy/services/dietitian_tip_service.dart';
import 'package:belly_buddy/models/recommendation_item.dart';
import 'package:belly_buddy/models/replacement_ingredient.dart';
import 'package:belly_buddy/models/user_recipe.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/screens/discover/widgets/discover_recipes_section.dart';
import 'package:belly_buddy/screens/discover/widgets/discover_tips_section.dart';
import 'package:belly_buddy/widgets/common/weekly_tips_switch.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/discover_news_provider.dart';
import 'package:belly_buddy/providers/ingredient_suggestion_provider.dart';
import 'package:belly_buddy/providers/recommendation_provider.dart';
import 'package:belly_buddy/providers/relief_provider.dart';
import 'package:belly_buddy/services/relief/relief_content.dart';
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
import '../../helpers/dietitian_tip_fakes.dart';
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
  setUpAll(() => initializeDateFormatting('de_DE', null));

  late FakeProfileRepository profileRepo;
  late MockRecommendationRepository recommendations;
  late MockIngredientRepository ingredients;
  late MockUserRecipeRepository recipes;
  late RecordingUrlOpener launches;
  late FakeKnowledgeRepository knowledge;
  late FakeRecipeRepository collection;
  late FakeDietitianTipService tipService;

  setUp(() {
    recommendations = MockRecommendationRepository();
    ingredients = MockIngredientRepository();
    recipes = MockUserRecipeRepository();
    launches = RecordingUrlOpener();
    knowledge = FakeKnowledgeRepository();
    profileRepo = FakeProfileRepository();
    collection = FakeRecipeRepository();
    SharedPreferences.setMockInitialValues({});
    tipService = FakeDietitianTipService();
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
    List<String>? intolerances,
    // How the tips load, in place of answering [tips].
    Future<List<Recommendation>> Function()? fetchTips,
    // Whether „Ruhe für den Bauch" is on; off shows its teaser on top.
    bool relief = false,
    List<DietitianTip> dietitianTips = const [],
  }) async {
    tipService.tips = List.of(dietitianTips);
    when(
      () => recommendations.fetchByUserId(any()),
    ).thenAnswer((_) => fetchTips?.call() ?? Future.value(tips));
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
          RoutePaths.discoverRecipes,
          RoutePaths.collectionRecipe,
          RoutePaths.knowledge,
          RoutePaths.relief,
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
      recipeRepositoryProvider.overrideWithValue(collection),
      dietitianTipServiceProvider.overrideWithValue(tipService),
      entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
      // No Buddy: the picks reads the progress, which asks for it.
      buddyProvider.overrideWith(() => FakeBuddyNotifier(() => null)),
      reliefEnabledProvider.overrideWithValue(relief),
      if (weeklyTips != null || intolerances != null)
        profileProviderSeededWith(
          testUserProfile(
            weeklyTipsEnabled: weeklyTips ?? true,
            intolerances: intolerances,
          ),
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

  /// The section titles' tops, from the top of the screen.
  List<double> sectionTops(WidgetTester tester, List<String> titles) => [
    for (final title in titles) tester.getTopLeft(find.text(title)).dy,
  ];

  group('Tipps', () {
    final optIn = find.byKey(DiscoverTipsSection.optInKey);
    final someTips = [
      testRecommendation(
        id: 'new',
        recommendations: const [_item],
        createdAt: DateTime.utc(2026, 11, 16, 10),
      ),
    ];

    /// No Tipps section at all, Alternativen right under the relief teaser.
    void expectNoTipps(WidgetTester tester) {
      expect(find.text('Tipps'), findsNothing);
      expect(find.byKey(DiscoverScreen.tipsKey), findsNothing);
      expect(optIn, findsNothing);
      expect(find.byKey(WeeklyTipsSwitch.switchKey), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(DiscoverScreen.alternativesKey)).dy,
        tester.getBottomLeft(find.byKey(DiscoverScreen.reliefTeaserKey)).dy +
            AppConstants.spacingLg,
      );
    }

    testWidgets('no tips, weekly tips off: no Tipps section at all', (
      tester,
    ) async {
      await pump(tester, weeklyTips: false);

      expectNoTipps(tester);
    });

    testWidgets('no tips, weekly tips on: no Tipps section, no note', (
      tester,
    ) async {
      await pump(tester, weeklyTips: true);

      expectNoTipps(tester);
      expect(find.textContaining('Montag'), findsNothing);
    });

    testWidgets('a newest set without tips alone: no Tipps section', (
      tester,
    ) async {
      await pump(
        tester,
        weeklyTips: false,
        tips: [
          testRecommendation(
            recommendations: const [],
            createdAt: DateTime.utc(2026, 11, 16, 10),
          ),
        ],
      );

      expectNoTipps(tester);
    });

    testWidgets('the first load still running: no Tipps section, nothing '
        'flashes', (tester) async {
      final load = Completer<List<Recommendation>>();
      await pump(tester, weeklyTips: false, fetchTips: () => load.future);

      expect(find.text('Tipps'), findsNothing);
      expect(
        find.text('Laden…'),
        findsNothing,
        reason: 'the other sections have loaded',
      );
      expect(find.byKey(DiscoverScreen.tipsKey), findsNothing);
      expect(optIn, findsNothing);

      load.complete(someTips);
      await tester.pumpAndSettle();

      expect(find.text('Tipps'), findsOneWidget);
      expect(find.byKey(DiscoverScreen.tipsKey), findsOneWidget);
      expect(optIn, findsOneWidget);
    });

    testWidgets('a failed first load: no Tipps section, no error line', (
      tester,
    ) async {
      await pump(
        tester,
        weeklyTips: false,
        fetchTips: () => Future.error(Exception('offline')),
      );

      expect(find.text('Tipps'), findsNothing);
      expect(find.byKey(DiscoverScreen.tipsKey), findsNothing);
      expect(find.textContaining('konnten nicht geladen werden'), findsNothing);
    });

    testWidgets('off, with tips: set card and opt-in', (tester) async {
      await pump(tester, weeklyTips: false, tips: someTips);

      expect(find.byKey(DiscoverScreen.tipsKey), findsOneWidget);
      expect(optIn, findsOneWidget);
    });

    testWidgets('on, with tips: no switch', (tester) async {
      await pump(tester, weeklyTips: true, tips: someTips);

      expect(find.byKey(DiscoverScreen.tipsKey), findsOneWidget);
      expect(find.byKey(WeeklyTipsSwitch.switchKey), findsNothing);
    });

    testWidgets('profile unknown, with tips: the card, no switch', (
      tester,
    ) async {
      await pump(tester, tips: someTips);

      expect(find.byKey(DiscoverScreen.tipsKey), findsOneWidget);
      expect(find.byKey(WeeklyTipsSwitch.switchKey), findsNothing);
    });

    testWidgets('with tips and weekly tips off: switching on drops the '
        'switch, the card stays', (tester) async {
      profileRepo.seedProfile(testUserProfile(weeklyTipsEnabled: false));
      await pump(tester, weeklyTips: false, tips: someTips);

      await tester.tapVisible(find.byKey(WeeklyTipsSwitch.switchKey));

      expect(profileRepo.weeklyTipsWrites, [true]);
      expect(find.byKey(WeeklyTipsSwitch.switchKey), findsNothing);
      expect(optIn, findsNothing);
      expect(find.byKey(DiscoverScreen.tipsKey), findsOneWidget);
      expect(find.text('Woche 47'), findsOneWidget);
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
    await pump(tester, tips: [testRecommendation()]);

    final tops = sectionTops(tester, [
      'Tipps',
      'Alternativen',
      'Rezepte',
      'Wissen',
    ]);
    expect(tops, orderedEquals([...tops]..sort()));
    expect(tops.toSet(), hasLength(4));
  });

  group('Ruhe für den Bauch', () {
    testWidgets('on: the card sits on top, above Tipps and Alternativen', (
      tester,
    ) async {
      await pump(tester, relief: true, tips: [testRecommendation()]);

      final card = find.byKey(DiscoverScreen.reliefKey);
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text(ReliefCopy.title)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text(ReliefCopy.cardSubtitle)),
        findsOneWidget,
      );
      final top = tester.getTopLeft(card).dy;
      expect(
        top,
        lessThan(tester.getTopLeft(find.byKey(DiscoverScreen.tipsKey)).dy),
      );
      expect(
        top,
        lessThan(
          tester.getTopLeft(find.byKey(DiscoverScreen.alternativesKey)).dy,
        ),
      );
      expect(
        tester.getSize(card).height,
        greaterThanOrEqualTo(AppConstants.minTapTarget),
      );
    });

    testWidgets('a tap opens /relief', (tester) async {
      await pump(tester, relief: true);

      await tester.tapVisible(find.byKey(DiscoverScreen.reliefKey));

      expect(find.text('page:${RoutePaths.relief}'), findsOneWidget);
    });

    testWidgets('on: no teaser, no „Kommt bald"', (tester) async {
      await pump(tester, relief: true);

      expect(find.byKey(DiscoverScreen.reliefTeaserKey), findsNothing);
      expect(find.text(ReliefCopy.comingSoon), findsNothing);
    });

    testWidgets('off: the teaser on top instead of the card', (tester) async {
      await pump(tester, tips: [testRecommendation()]);

      expect(find.byKey(DiscoverScreen.reliefKey), findsNothing);
      final teaser = find.byKey(DiscoverScreen.reliefTeaserKey);
      expect(teaser, findsOneWidget);
      for (final text in [
        ReliefCopy.title,
        ReliefCopy.teaserLine,
        ReliefCopy.comingSoon,
      ]) {
        expect(
          find.descendant(of: teaser, matching: find.text(text)),
          findsOneWidget,
        );
      }
      expect(find.text(ReliefCopy.cardSubtitle), findsNothing);
      expect(
        tester.getTopLeft(teaser).dy,
        lessThan(tester.getTopLeft(find.byKey(DiscoverScreen.tipsKey)).dy),
      );
    });

    testWidgets('off: a tap on the teaser opens nothing', (tester) async {
      await pump(tester);

      await tester.tapVisible(find.byKey(DiscoverScreen.reliefTeaserKey));
      await tester.pumpAndSettle();

      expect(find.text('page:${RoutePaths.relief}'), findsNothing);
      expect(find.byKey(DiscoverScreen.reliefTeaserKey), findsOneWidget);
    });

    testWidgets('off: the teaser reads as one item, not a button', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);

      expect(
        tester.getSemantics(find.byKey(DiscoverScreen.reliefTeaserKey)),
        matchesSemantics(
          label:
              '${ReliefCopy.title}\n${ReliefCopy.teaserLine}\n'
              '${ReliefCopy.comingSoon}',
        ),
      );
      semantics.dispose();
    });
  });

  testWidgets('without tips: Alternativen, Rezepte, Wissen', (tester) async {
    await pump(tester);

    expect(find.text('Tipps'), findsNothing);
    final tops = sectionTops(tester, ['Alternativen', 'Rezepte', 'Wissen']);
    expect(tops, orderedEquals([...tops]..sort()));
    expect(tops.toSet(), hasLength(3));
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

  for (final seen in [true, false]) {
    testWidgets('a newest set without tips is skipped: the card shows the '
        'older one with tips, „Neu" as it is${seen ? ' seen' : ' unseen'} '
        '(as for Home and the Buddy)', (tester) async {
      await pump(
        tester,
        tips: [
          testRecommendation(
            id: 'empty',
            recommendations: const [],
            createdAt: DateTime.utc(2026, 11, 16, 10),
          ),
          testRecommendation(
            id: 'old',
            recommendations: const [_item],
            createdAt: DateTime.utc(2026, 11, 9, 10),
            seenAt: seen ? DateTime.utc(2026, 11, 10, 7) : null,
          ),
        ],
      );

      expect(
        inSection(DiscoverScreen.tipsKey, find.text('Woche 46')),
        findsOneWidget,
      );
      expect(find.text('Woche 47'), findsNothing);
      expect(
        inSection(DiscoverScreen.tipsKey, find.text('1 Tipp')),
        findsOneWidget,
      );
      expect(
        inSection(DiscoverScreen.tipsKey, find.text('Neu')),
        seen ? findsNothing : findsOneWidget,
      );
    });
  }

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
        IngredientSuggestionGroup(
          ingredientId: 'ing-1',
          ingredientName: 'Zwiebel',
          mealCount: 1,
          isNew: false,
          suggestionIds: ['sug-1'],
          replacements: RankedReplacement.inOrder(const [
            ReplacementIngredient(id: 'r1', name: 'Schnittlauch'),
            ReplacementIngredient(id: 'r2', name: 'Lauchgrün'),
          ]),
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

  testWidgets('„Stattdessen:" leaves out the ones that do not fit', (
    tester,
  ) async {
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
            RankedReplacement(
              replacement: ReplacementIngredient(id: 'r2', name: 'Lauchgrün'),
            ),
            RankedReplacement(
              replacement: ReplacementIngredient(
                id: 'r1',
                name: 'Schnittlauch',
              ),
              verdict: AlternativeChoiceKind.skip,
              tier: 4,
            ),
          ],
        ),
        const IngredientSuggestionGroup(
          ingredientId: 'ing-2',
          ingredientName: 'Knoblauch',
          mealCount: 1,
          isNew: false,
          suggestionIds: ['sug-2'],
          replacements: [
            RankedReplacement(
              replacement: ReplacementIngredient(id: 'r3', name: 'Asafoetida'),
              verdict: AlternativeChoiceKind.skip,
              tier: 4,
            ),
          ],
        ),
      ],
    );

    expect(find.text('Stattdessen: Lauchgrün'), findsOneWidget);
    expect(find.textContaining('Schnittlauch'), findsNothing);
    // Every one skipped: no line.
    expect(find.text('Knoblauch'), findsOneWidget);
    expect(find.textContaining('Asafoetida'), findsNothing);
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

    await tester.tapVisible(find.bySemanticsLabel('Alle meine Rezepte'));
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

    await tester.tapVisible(find.bySemanticsLabel('Alle meine Rezepte'));
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Keine Treffer'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(DiscoverScreen), findsOneWidget);
    expect(find.text('Noch keine Rezepte.'), findsNothing);
    expect(find.byType(RecipeCard), findsNWidgets(2));
    expect(find.bySemanticsLabel('Alle meine Rezepte'), findsOneWidget);
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

    expect(
      inSection(
        DiscoverRecipesSection.mineKey,
        find.text('Noch keine Rezepte.'),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Alle meine Rezepte'), findsNothing);
    await tester.tapVisible(find.text('Erstes Rezept erstellen'));
    expect(find.text('Rezept hinzufügen'), findsOneWidget);
  });

  group('Von deiner Berater:in', () {
    testWidgets('no tip: no section', (tester) async {
      await pump(tester);
      expect(find.text('Von deiner Berater:in'), findsNothing);
    });

    testWidgets('a tip: the section sits above Tipps, loaded by _load', (
      tester,
    ) async {
      await pump(
        tester,
        weeklyTips: false,
        tips: [
          testRecommendation(
            id: 'r',
            recommendations: const [_item],
            createdAt: DateTime.utc(2026, 11, 16, 10),
          ),
        ],
        dietitianTips: [testTip(body: 'Mehr trinken.')],
      );

      expect(tipService.listCalls, greaterThanOrEqualTo(1));
      expect(find.text('Mehr trinken.'), findsOneWidget);
      final tops = sectionTops(tester, ['Von deiner Berater:in', 'Tipps']);
      expect(tops[0], lessThan(tops[1]));
      expect(tipService.seenCalls, [
        ['t1'],
      ]);
    });

    testWidgets('pull to refresh loads the tips again', (tester) async {
      await pump(tester, dietitianTips: [testTip()]);
      final before = tipService.listCalls;
      tipService.tips = [
        testTip(id: 't2', body: 'Neuer Tipp.'),
        ...tipService.tips,
      ];

      await tester.fling(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(tipService.listCalls, greaterThan(before));
      expect(find.text('Neuer Tipp.'), findsOneWidget);
    });
  });

  group('Rezepte', () {
    final milch = testLine('Milch', fodmaps: const FodmapFlags(lactose: true));

    Finder forYou(Finder f) => inSection(DiscoverRecipesSection.forYouKey, f);
    Finder mine(Finder f) => inSection(DiscoverRecipesSection.mineKey, f);

    testWidgets('Für dich shows 3 ranked cards with badges', (tester) async {
      collection.collection = [
        testRecipe(id: 'a', title: 'Reisbowl'),
        testRecipe(id: 'b', title: 'Milchreis', ingredients: [milch]),
        testRecipe(id: 'c', title: 'Gemüsepfanne'),
        testRecipe(id: 'd', title: 'Nudeln'),
        testRecipe(id: 'e', title: 'Suppe'),
      ];
      await pump(tester, intolerances: const ['Laktose']);

      expect(forYou(find.byType(RecipeCollectionCard)), findsNWidgets(3));
      // The kritisch one is ranked after those that fit.
      expect(forYou(find.text('Milchreis')), findsNothing);
      expect(forYou(find.text(RecipeCopy.fits)), findsNWidgets(3));
    });

    testWidgets('Alle › opens the Rezepte list', (tester) async {
      await pump(tester);

      await tester.tapVisible(
        find
            .descendant(
              of: find.byKey(DiscoverScreen.recipesKey),
              matching: find.text('Alle ›'),
            )
            .first,
      );
      expect(find.text('page:${RoutePaths.discoverRecipes}'), findsOneWidget);
    });

    testWidgets('a Für dich card opens the collection recipe', (tester) async {
      await pump(tester);

      await tester.tapVisible(forYou(find.byType(RecipeCollectionCard)));
      expect(find.text('page:${RoutePaths.collectionRecipe}'), findsOneWidget);
    });

    testWidgets('Meine Rezepte: own and gemerkte by date, the gemerkte '
        'with a heart', (tester) async {
      collection.collection = [testRecipe(id: 'g', title: 'Gemerktes')];
      collection.favorites = [FavoriteRecipe('g', DateTime(2026, 11, 20))];
      await pump(
        tester,
        myRecipes: [
          testUserRecipe(
            id: 'new',
            title: 'Neu geschrieben',
            createdAt: DateTime(2026, 11, 22),
          ),
          testUserRecipe(
            id: 'old',
            title: 'Alt geschrieben',
            createdAt: DateTime(2026, 11, 10),
          ),
        ],
      );

      final tops = [
        for (final t in ['Neu geschrieben', 'Gemerktes', 'Alt geschrieben'])
          tester.getTopLeft(mine(find.text(t))).dx,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
      expect(mine(find.byType(RecipeTagPill)), findsOneWidget);
      expect(mine(find.byIcon(Icons.favorite)), findsOneWidget);

      await tester.tapVisible(mine(find.text('Gemerktes')));
      expect(find.text('page:${RoutePaths.collectionRecipe}'), findsOneWidget);
    });

    testWidgets('saved only, while they load: Laden…, no empty state', (
      tester,
    ) async {
      final gated = _GatedFavorites()
        ..collection = [testRecipe(id: 'g', title: 'Gemerktes')]
        ..favorites = [FavoriteRecipe('g', DateTime(2026, 11, 20))];
      collection = gated;
      await pump(tester);

      expect(mine(find.text('Laden…')), findsOneWidget);
      expect(mine(find.text('Noch keine Rezepte.')), findsNothing);
      expect(mine(find.text('Erstes Rezept erstellen')), findsNothing);

      gated.load.complete();
      await tester.pumpAndSettle();
      expect(mine(find.text('Gemerktes')), findsOneWidget);
      expect(mine(find.text('Laden…')), findsNothing);
    });

    testWidgets('saved recipes offline: no own recipes still offers the '
        'first one, with a quiet line and a retry', (tester) async {
      // Offline: the collection's and the favourites' reads fail.
      collection
        ..collectionError = const SocketException('Failed host lookup')
        ..favoritesError = const SocketException('Failed host lookup');
      await pump(tester);

      expect(mine(find.text('Noch keine Rezepte.')), findsOneWidget);
      expect(mine(find.text('Erstes Rezept erstellen')), findsOneWidget);
      expect(mine(find.text(RecipeCopy.savedFailed)), findsOneWidget);

      // Back: the retry brings the saved ones, the line goes.
      collection
        ..collectionError = null
        ..favoritesError = null
        ..collection = [testRecipe(id: 'g', title: 'Gemerktes')]
        ..favorites = [FavoriteRecipe('g', DateTime(2026, 11, 20))];
      await tester.tapVisible(mine(find.text(RecipeCopy.retry)));
      expect(mine(find.text('Gemerktes')), findsOneWidget);
      expect(mine(find.text(RecipeCopy.savedFailed)), findsNothing);
      expect(mine(find.text('Erstes Rezept erstellen')), findsNothing);
    });

    testWidgets('own recipes and the saved ones failed: the own ones and '
        'the quiet line', (tester) async {
      collection.favoritesError = StateError('offline');
      await pump(tester, myRecipes: [testUserRecipe(title: 'Eigenes')]);

      expect(mine(find.text('Eigenes')), findsOneWidget);
      expect(mine(find.text(RecipeCopy.savedFailed)), findsOneWidget);
    });

    testWidgets('saved ones loaded: no quiet line', (tester) async {
      await pump(tester);

      expect(find.text(RecipeCopy.savedFailed), findsNothing);
    });

    testWidgets('collection fails: own recipes still shown', (tester) async {
      collection.collectionError = Exception('404');
      await pump(tester, myRecipes: [testUserRecipe(title: 'Eigenes')]);

      expect(
        forYou(find.text('Rezepte konnten nicht geladen werden.')),
        findsOneWidget,
      );
      expect(mine(find.byType(RecipeCard)), findsOneWidget);
      expect(mine(find.text('Eigenes')), findsOneWidget);
    });

    testWidgets('pull to refresh reloads the collection and failed rules', (
      tester,
    ) async {
      collection.rulesError = StateError('offline');
      await pump(tester, intolerances: const ['Fruktose']);
      expect(forYou(find.text('Testrezept')), findsOneWidget);
      expect(forYou(find.byType(FitBadgeView)), findsNothing);
      final rules = collection.rulesFetches;
      final favorites = collection.favoritesFetches;

      collection
        ..rulesError = null
        ..collection = [testRecipe(id: 'n', title: 'Neues Rezept')];
      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(forYou(find.text('Neues Rezept')), findsOneWidget);
      expect(forYou(find.text('Testrezept')), findsNothing);
      expect(forYou(find.byType(FitBadgeView)), findsOneWidget);
      expect(collection.rulesFetches, rules + 1);
      expect(collection.favoritesFetches, favorites + 1);
    });

    testWidgets('no header „Alle ›" without Für dich recipes', (tester) async {
      collection.collection = [];
      await pump(tester, myRecipes: [testUserRecipe()]);
      expect(
        find.descendant(
          of: find.byKey(DiscoverRecipesSection.sectionKey),
          matching: find.text('Alle ›'),
        ),
        findsOneWidget, // only Meine Rezepte's
      );
      expect(find.bySemanticsLabel('Alle meine Rezepte'), findsOneWidget);
    });

    testWidgets('no header „Alle ›" when the collection fails', (tester) async {
      collection.collectionError = Exception('404');
      await pump(tester);
      expect(
        find.descendant(
          of: find.byKey(DiscoverRecipesSection.sectionKey),
          matching: find.text('Alle ›'),
        ),
        findsNothing,
      );
    });

    testWidgets('fits 375×667 at text scale 1.3', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      collection.collection = [
        for (var i = 0; i < 4; i++)
          testRecipe(
            id: 'c$i',
            title: 'Ein Sammlungsrezept mit einem langen Namen $i',
            ingredients: [milch],
          ),
      ];
      collection.favorites = [FavoriteRecipe('c0', DateTime(2026, 11, 20))];

      await pump(
        tester,
        textScale: 1.3,
        intolerances: const ['Laktose'],
        myRecipes: [testUserRecipe(title: 'Ein langes Rezept zum Testen')],
      );

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(DiscoverRecipesSection.mineKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
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

  group('Wissen: Für dich', () {
    // Older than the fixtures' newest three, so only a pick shows it.
    final laktose = KnowledgeArticle(
      title: 'Laktose im Alltag',
      link: Uri.parse('https://www.myfodmap.at/laktose'),
      category: 'Gesund verdauen',
      publishedAt: DateTime.utc(2026, 9, 1, 8),
    );

    List<String> tileTitles(WidgetTester tester) => [
      for (final t in tester.widgetList<KnowledgeArticleTile>(
        tilesIn(DiscoverScreen.knowledgeKey),
      ))
        t.article.title,
    ];

    testWidgets('Entdecken: picks first with reason, filled to 3 with the '
        'newest', (tester) async {
      knowledge = FakeKnowledgeRepository(
        articles: [...testKnowledgeArticles(), laktose],
      );
      await pump(tester, intolerances: const ['Laktose']);

      expect(tileTitles(tester), [
        'Laktose im Alltag',
        'Was ist FODMAP?',
        'Suppe für kalte Tage',
      ]);
      final pick = find.byKey(KnowledgeArticleTile.keyFor(laktose));
      expect(
        find.descendant(
          of: pick,
          matching: find.text('Weil du Laktose angegeben hast'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: pick,
          matching: find.text('Gesund verdauen · 1. Sep 2026'),
        ),
        findsNothing,
      );
      expect(find.text('Rezepte · 10. Nov 2026'), findsOneWidget);
      expect(
        tester.getSemantics(pick),
        isSemantics(
          label: 'Laktose im Alltag, Weil du Laktose angegeben hast',
          isButton: true,
        ),
      );
    });

    testWidgets('Entdecken: no pick → newest 3 with meta lines, as before', (
      tester,
    ) async {
      await pump(tester, intolerances: const ['Laktose']);

      expect(tileTitles(tester), [
        'Was ist FODMAP?',
        'Suppe für kalte Tage',
        'Mein Weg zum Bauchgefühl',
      ]);
      expect(find.text('Gesund verdauen · 20. Nov 2026'), findsOneWidget);
      expect(find.textContaining('Weil '), findsNothing);
    });

    testWidgets('Entdecken: tapping a pick marks it opened and opens it', (
      tester,
    ) async {
      knowledge = FakeKnowledgeRepository(
        articles: [...testKnowledgeArticles(), laktose],
      );
      await pump(tester, intolerances: const ['Laktose']);

      await tester.tapVisible(find.byKey(KnowledgeArticleTile.keyFor(laktose)));

      expect(launches.urls, [laktose.link]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('knowledge_opened_$testUserId'), [
        laktose.link.toString(),
      ]);
      expect(tileTitles(tester), [
        'Was ist FODMAP?',
        'Suppe für kalte Tage',
        'Mein Weg zum Bauchgefühl',
      ]);
    });
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

/// The favourites answer once [load] completes.
class _GatedFavorites extends FakeRecipeRepository {
  final load = Completer<void>();

  @override
  Future<List<FavoriteRecipe>> fetchFavorites(String userId) async {
    await load.future;
    return super.fetchFavorites(userId);
  }
}
