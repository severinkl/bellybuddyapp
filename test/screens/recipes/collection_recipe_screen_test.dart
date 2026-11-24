import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/fodmap_flags.dart';
import 'package:belly_buddy/models/meal_prefill.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/recipes/collection_recipe_screen.dart';
import 'package:belly_buddy/screens/recipes/widgets/fit_badge_view.dart';
import 'package:belly_buddy/screens/recipes/widgets/ingredient_line_view.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_image.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_steps.dart';
import 'package:belly_buddy/services/recipes/recipe_copy.dart';
import 'package:belly_buddy/widgets/common/bb_async_state.dart';

import '../../helpers/app_host.dart';
import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/layout_checks.dart';
import '../../helpers/riverpod_helpers.dart';
import '../../helpers/widget_tester_helpers.dart';

void main() {
  late FakeRecipeRepository repo;
  late RecordingUrlOpener launches;
  late Map<String, Object?> pushed;

  final reis = testLine('Reis', position: 0, amount: '200 g');
  final honig = testLine(
    'Honig',
    position: 1,
    amount: '1 EL',
    fodmaps: const FodmapFlags(fructose: true),
  );
  const sourceUrl = 'https://www.reizdarmblog.de/reis-mit-honig';

  Recipe recipe({
    List<RecipeIngredient>? ingredients,
    List<String> instructions = const ['Reis kochen.', 'Honig unterrühren.'],
    String? sourceName = 'Reizdarmblog',
    String? source = sourceUrl,
  }) => testRecipe(
    title: 'Reis mit Honig',
    cookTime: '35 Min',
    ingredients: ingredients ?? [reis, honig],
    instructions: instructions,
    sourceName: sourceName,
    sourceUrl: source,
  );

  setUp(() {
    repo = FakeRecipeRepository()..collection = [recipe()];
    launches = RecordingUrlOpener();
    pushed = {};
  });

  Future<void> pump(
    WidgetTester tester, {
    List<String> intolerances = const ['Fruktose'],
    String id = 'recipe-1',
    double textScale = 1,
  }) async {
    GoRoute stub(String path) => GoRoute(
      path: path,
      builder: (_, state) {
        pushed[state.uri.path] = state.extra;
        return Scaffold(body: Text('page:${state.uri.path}'));
      },
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              CollectionRecipeScreen(recipeId: id, openUrl: launches.call),
        ),
        stub(RoutePaths.collectionRecipeAdapt),
        stub(RoutePaths.mealTracker),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recipeRepositoryProvider.overrideWithValue(repo),
          profileProviderSeededWith(
            testUserProfile(intolerances: intolerances),
          ),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: germanRouterApp(router, textScale: textScale),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder line(String name) =>
      find.byWidgetPredicate((w) => w is IngredientLineView && w.name == name);

  Finder inLine(String name, Finder finder) =>
      find.descendant(of: line(name), matching: finder);

  Finder inSave(Finder finder) => find.descendant(
    of: find.byKey(CollectionRecipeScreen.saveKey),
    matching: finder,
  );

  const adaptHint = 'Ich tausche Honig und schreibe die Schritte passend um.';

  testWidgets('shows the recipe: image, title, meta and servings', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Rezept')),
      findsOneWidget,
    );
    expect(find.text('Reis mit Honig'), findsOneWidget);
    expect(find.text('35 Min · 2 Portionen'), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(find.text('Zutaten'), findsOneWidget);
    expect(find.text('für 2 Portionen'), findsOneWidget);
    expect(find.byKey(RecipePlaceholder.placeholderKey), findsOneWidget);
  });

  testWidgets('marks each ingredient', (tester) async {
    await pump(tester);

    expect(inLine('Reis', find.byIcon(Icons.check)), findsOneWidget);
    expect(find.text('200 g'), findsOneWidget);
    expect(find.text('Honig — für dich kritisch'), findsOneWidget);
    expect(find.text('wegen Fruktose'), findsOneWidget);
    expect(
      inLine('Honig', find.byIcon(Icons.warning_amber_rounded)),
      findsOneWidget,
    );
    expect(find.text('1 Zutat ist für dich kritisch'), findsOneWidget);
    expect(find.text('Passt zu dir'), findsNothing);
  });

  testWidgets('kritisch → Für mich anpassen with the hint', (tester) async {
    await pump(tester);

    expect(find.text('Für mich anpassen'), findsOneWidget);
    expect(find.text(adaptHint), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(CollectionRecipeScreen.adaptKey),
        matching: find.byIcon(Icons.auto_awesome),
      ),
      findsOneWidget,
    );

    await tester.tapVisible(find.byKey(CollectionRecipeScreen.adaptKey));

    expect(find.text('page:/collection/recipe-1/adapt'), findsOneWidget);
    expect(pushed, {'/collection/recipe-1/adapt': true});
  });

  testWidgets('nothing kritisch → no adapt button', (tester) async {
    repo.collection = [
      recipe(ingredients: [reis]),
    ];
    await pump(tester);

    expect(find.text('Passt zu dir'), findsOneWidget);
    expect(inLine('Reis', find.byIcon(Icons.check)), findsOneWidget);
    expect(find.byKey(CollectionRecipeScreen.adaptKey), findsNothing);
    expect(find.text('Für mich anpassen'), findsNothing);
  });

  testWidgets('Histamin user', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, intolerances: const ['Histamin']);

    expect(find.text('Histamin bitte selbst prüfen'), findsOneWidget);
    expect(find.text('Passt zu dir'), findsNothing);
    expect(find.text('Honig — für dich kritisch'), findsNothing);
    expect(find.byKey(CollectionRecipeScreen.adaptKey), findsNothing);
    // No ✓ and no „passt": that would read like a verdict on Histamin.
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'\bpasst\b')), findsNothing);
    expect(inLine('Reis', find.byKey(IngredientLineView.neutralKey)), findsOne);
    expect(tester.getSemantics(line('Reis')).label, '200 g Reis');
    semantics.dispose();
  });

  testWidgets('Laktose and Histamin user', (tester) async {
    final quark = testLine(
      'Quark',
      position: 1,
      amount: '250 g',
      fodmaps: const FodmapFlags(lactose: true),
    );
    repo.collection = [
      recipe(ingredients: [reis, quark]),
    ];
    await pump(tester, intolerances: const ['Laktose', 'Histamin']);

    expect(find.text('Quark — für dich kritisch'), findsOneWidget);
    expect(find.text('wegen Laktose'), findsOneWidget);
    expect(
      inLine('Quark', find.byIcon(Icons.warning_amber_rounded)),
      findsOneWidget,
    );
    expect(inLine('Reis', find.byKey(IngredientLineView.neutralKey)), findsOne);
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.text('1 Zutat ist für dich kritisch'), findsOneWidget);
    expect(
      find.text('Ich tausche Quark und schreibe die Schritte passend um.'),
      findsOneWidget,
    );
  });

  testWidgets('rules missing: no badge, no marks, no adapt button', (
    tester,
  ) async {
    repo.rules = null;
    await pump(tester);

    expect(find.byType(FitBadgeView), findsNothing);
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    expect(find.text('Honig — für dich kritisch'), findsNothing);
    expect(find.byKey(CollectionRecipeScreen.adaptKey), findsNothing);
    // The lines are still there, unmarked.
    expect(line('Reis'), findsOneWidget);
    expect(line('Honig'), findsOneWidget);
    expect(find.text('1 EL'), findsOneWidget);
  });

  testWidgets('an older recipe shows its lines unmarked, no adapt button', (
    tester,
  ) async {
    repo.collection = [
      const Recipe(
        id: 'recipe-1',
        title: 'Alter Eintopf',
        legacyIngredients: ['2 Karotten', '1 Zwiebel'],
      ),
    ];
    await pump(tester);

    expect(line('2 Karotten'), findsOneWidget);
    expect(line('1 Zwiebel'), findsOneWidget);
    // No amounts: the text lines start at the left, without the column.
    expect(
      tester.getTopLeft(find.text('2 Karotten')).dx,
      tester.getTopLeft(line('2 Karotten')).dx,
    );
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    expect(find.byKey(CollectionRecipeScreen.adaptKey), findsNothing);
    expect(find.text('Zubereitung'), findsNothing);
    expect(find.byKey(CollectionRecipeScreen.sourceKey), findsNothing);
  });

  testWidgets('lines without amounts start at the left', (tester) async {
    repo.collection = [
      recipe(ingredients: [testLine('Reis'), testLine('Salz', position: 1)]),
    ];
    await pump(tester);

    for (final name in ['Reis', 'Salz']) {
      expect(
        tester.getTopLeft(find.text(name)).dx -
            tester.getTopLeft(line(name)).dx,
        AppConstants.recipeMarkSize + AppConstants.spacing10,
        reason: name,
      );
    }
  });

  testWidgets('steps numbered', (tester) async {
    await pump(tester);

    expect(find.text('Zubereitung'), findsOneWidget);
    expect(find.text('Reis kochen.'), findsOneWidget);
    expect(find.text('Honig unterrühren.'), findsOneWidget);
    for (final (i, n) in [(0, '1'), (1, '2')]) {
      expect(
        find.descendant(
          of: find.byKey(RecipeSteps.numberKey(i)),
          matching: find.text(n),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('no steps → no Zubereitung', (tester) async {
    repo.collection = [recipe(instructions: const [])];
    await pump(tester);

    expect(find.text('Zubereitung'), findsNothing);
    expect(find.byType(RecipeSteps), findsNothing);
  });

  group('Quelle', () {
    testWidgets('Quelle opens in the in-app browser', (tester) async {
      await pump(tester);

      expect(find.text('Quelle: Reizdarmblog ›'), findsOneWidget);
      await tester.tapVisible(find.byKey(CollectionRecipeScreen.sourceKey));

      expect(launches.urls, [Uri.parse(sourceUrl)]);
      expect(launches.modes, [LaunchMode.inAppBrowserView]);
      expect(find.text(RecipeCopy.sourceFailed), findsNothing);
    });

    testWidgets('a failure says so', (tester) async {
      launches.result = false;
      await pump(tester);

      await tester.tapVisible(find.byKey(CollectionRecipeScreen.sourceKey));

      expect(launches.urls, hasLength(1));
      expect(find.text(RecipeCopy.sourceFailed), findsOneWidget);
    });

    testWidgets('without a name, the site', (tester) async {
      repo.collection = [recipe(sourceName: null)];
      await pump(tester);

      expect(find.text('Quelle: www.reizdarmblog.de ›'), findsOneWidget);
    });

    testWidgets('hidden without a link', (tester) async {
      repo.collection = [recipe(source: null)];
      await pump(tester);

      expect(find.byKey(CollectionRecipeScreen.sourceKey), findsNothing);
      expect(find.textContaining('Quelle'), findsNothing);
    });

    testWidgets('hidden without a web link', (tester) async {
      repo.collection = [recipe(source: 'ftp://files.example.de/reis')];
      await pump(tester);

      expect(find.byKey(CollectionRecipeScreen.sourceKey), findsNothing);
    });

    testWidgets('opens the link trimmed', (tester) async {
      repo.collection = [recipe(source: '  $sourceUrl ')];
      await pump(tester);

      await tester.tapVisible(find.byKey(CollectionRecipeScreen.sourceKey));

      expect(launches.urls, [Uri.parse(sourceUrl)]);
    });
  });

  group('Merken', () {
    testWidgets('toggles to Gemerkt and back', (tester) async {
      await pump(tester);
      expect(inSave(find.text('Merken')), findsOneWidget);
      expect(inSave(find.byIcon(Icons.favorite_border)), findsOneWidget);

      await tester.tap(find.byKey(CollectionRecipeScreen.saveKey));
      await tester.pumpAndSettle();

      expect(repo.added, ['recipe-1']);
      expect(inSave(find.text('Gemerkt')), findsOneWidget);
      final heart = tester.widget<Icon>(inSave(find.byIcon(Icons.favorite)));
      expect(heart.color, AppTheme.buddyHeart);
      expect(find.text(CollectionRecipeScreen.saved), findsOneWidget);

      await tester.tap(find.byKey(CollectionRecipeScreen.saveKey));
      await tester.pumpAndSettle();

      expect(repo.removed, ['recipe-1']);
      expect(inSave(find.text('Merken')), findsOneWidget);
      expect(find.text(CollectionRecipeScreen.unsaved), findsOneWidget);
      expect(find.text(CollectionRecipeScreen.saved), findsNothing);
    });

    testWidgets('a saved recipe opens as Gemerkt', (tester) async {
      repo.favorites = [FavoriteRecipe('recipe-1', DateTime(2026, 11, 20))];
      await pump(tester);

      expect(inSave(find.text('Gemerkt')), findsOneWidget);
    });

    testWidgets('Merken offline reverts', (tester) async {
      repo.favoriteError = StateError('offline');
      await pump(tester);

      await tester.tap(find.byKey(CollectionRecipeScreen.saveKey));
      await tester.pumpAndSettle();

      expect(repo.added, ['recipe-1']);
      expect(inSave(find.text('Merken')), findsOneWidget);
      expect(find.text(RecipeCopy.failed), findsOneWidget);
      expect(find.text(CollectionRecipeScreen.saved), findsNothing);
    });

    testWidgets('after a failed load, fetches the saved recipes first', (
      tester,
    ) async {
      final failing = _FailingFavoritesOnce()
        ..collection = [recipe()]
        ..favorites = [FavoriteRecipe('recipe-1', DateTime(2026, 11, 20))];
      repo = failing;
      await pump(tester);
      expect(inSave(find.text('Merken')), findsOneWidget);

      await tester.tap(find.byKey(CollectionRecipeScreen.saveKey));
      await tester.pumpAndSettle();

      // It was saved: the tap takes it back instead of saving it twice.
      expect(failing.fetches, 2);
      expect(repo.removed, ['recipe-1']);
      expect(repo.added, isEmpty);
      expect(inSave(find.text('Merken')), findsOneWidget);
      expect(find.text(CollectionRecipeScreen.unsaved), findsOneWidget);
    });
  });

  testWidgets('Als Essen eintragen', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(CollectionRecipeScreen.logKey));
    await tester.pumpAndSettle();

    expect(find.text('page:${RoutePaths.mealTracker}'), findsOneWidget);
    final prefill = pushed[RoutePaths.mealTracker];
    expect(prefill, isA<MealPrefill>());
    prefill as MealPrefill;
    expect(prefill.title, 'Reis mit Honig');
    expect(prefill.ingredients, ['Reis', 'Honig']);
    expect(prefill.imageUrl, isNull);
  });

  testWidgets('collection fails: retry', (tester) async {
    repo.collectionError = StateError('offline');
    await pump(tester);

    expect(find.byType(BbErrorState), findsOneWidget);
    expect(find.text('Konnte das Rezept nicht laden'), findsOneWidget);
    expect(find.byKey(CollectionRecipeScreen.logKey), findsNothing);

    repo.collectionError = null;
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();

    expect(find.byType(BbErrorState), findsNothing);
    expect(find.text('Reis mit Honig'), findsOneWidget);
    expect(find.text('1 Zutat ist für dich kritisch'), findsOneWidget);
  });

  testWidgets('retry reloads rules that failed too', (tester) async {
    repo
      ..collectionError = StateError('offline')
      ..rulesError = StateError('offline');
    await pump(tester);
    expect(find.byType(BbErrorState), findsOneWidget);

    repo
      ..collectionError = null
      ..rulesError = null;
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();

    expect(repo.rulesFetches, 2);
    expect(find.text('1 Zutat ist für dich kritisch'), findsOneWidget);
  });

  testWidgets('loading → spinner', (tester) async {
    final gated = _GatedCollection();
    repo = gated;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recipeRepositoryProvider.overrideWithValue(repo),
          profileProviderSeededWith(testUserProfile()),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: const MaterialApp(
          home: CollectionRecipeScreen(recipeId: 'recipe-1'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Rezept'), findsOneWidget);
    expect(find.byKey(CollectionRecipeScreen.logKey), findsNothing);
  });

  testWidgets('unknown id', (tester) async {
    await pump(tester, id: 'nope');

    expect(find.text('Rezept nicht gefunden'), findsOneWidget);
    expect(find.byKey(CollectionRecipeScreen.logKey), findsNothing);
  });

  testWidgets('fits 375×667 at text scale 1.3', (tester) async {
    tester.view
      ..physicalSize = const Size(375, 667)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo.favorites = [FavoriteRecipe('recipe-1', DateTime(2026, 11, 20))];
    repo.collection = [
      recipe(
        ingredients: [
          reis,
          honig,
          testLine('Knoblauch', position: 2, amount: '2 Zehen'),
        ],
      ),
    ];

    final errors = await collectFlutterErrors(
      () => pump(tester, textScale: 1.3),
    );

    expect(find.text(adaptHint), findsOneWidget);
    expect(inSave(find.text('Gemerkt')), findsOneWidget);
    expect(verticalOverflows(errors), isEmpty);
    expect(errors, isEmpty);
  });
}

/// The collection never arrives.
class _GatedCollection extends FakeRecipeRepository {
  @override
  Future<List<Recipe>> fetchCollection() => Completer<List<Recipe>>().future;
}

/// The first favourites fetch fails, later ones answer.
class _FailingFavoritesOnce extends FakeRecipeRepository {
  var fetches = 0;

  @override
  Future<List<FavoriteRecipe>> fetchFavorites(String userId) async {
    if (++fetches == 1) throw StateError('offline');
    return super.fetchFavorites(userId);
  }
}
