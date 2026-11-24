import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/models/fodmap_flags.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/recipes/collection_screen.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_list_tile.dart';
import 'package:belly_buddy/widgets/common/bb_async_state.dart';

import '../../helpers/app_host.dart';
import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/layout_checks.dart';
import '../../helpers/riverpod_helpers.dart';

void main() {
  late FakeRecipeRepository repo;
  late Map<String, Object?> pushed;

  final milch = testLine('Milch', fodmaps: const FodmapFlags(lactose: true));

  Recipe dinner(String title, {List<RecipeIngredient>? lines}) => testRecipe(
    id: title,
    title: title,
    mealTypes: const [MealType.dinner],
    ingredients: lines,
  );

  setUp(() {
    repo = FakeRecipeRepository();
    pushed = {};
  });

  Future<void> pump(
    WidgetTester tester, {
    List<String> intolerances = const [],
    String? diet,
    double textScale = 1,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const CollectionScreen()),
        GoRoute(
          path: RoutePaths.collectionRecipe,
          builder: (_, state) {
            pushed[state.uri.path] = state.extra;
            return Scaffold(body: Text('page:${state.uri.path}'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recipeRepositoryProvider.overrideWithValue(repo),
          profileProviderSeededWith(
            testUserProfile(intolerances: intolerances, diet: diet),
          ),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: germanRouterApp(router, textScale: textScale),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tile(String title) => find.byWidgetPredicate(
    (w) => w is RecipeListTile && w.recipe.title == title,
  );

  testWidgets('chips filter by meal type', (tester) async {
    repo.collection = [
      testRecipe(id: 'a', title: 'Mittagsreis'),
      dinner('Abendsuppe'),
    ];
    await pump(tester);
    expect(find.byType(RecipeListTile), findsNWidgets(2));

    await tester.tap(find.byKey(CollectionScreen.chipKey(MealType.dinner)));
    await tester.pumpAndSettle();
    expect(tile('Abendsuppe'), findsOneWidget);
    expect(tile('Mittagsreis'), findsNothing);

    await tester.tap(find.byKey(CollectionScreen.chipKey(MealType.dinner)));
    await tester.pumpAndSettle();
    expect(find.byType(RecipeListTile), findsNWidgets(2));
  });

  testWidgets('Passt zu mir hides kritisch and unjudged recipes', (
    tester,
  ) async {
    repo.collection = [
      dinner('Reisbowl'),
      dinner('Milchreis', lines: [milch]),
      const Recipe(
        id: 'old',
        title: 'Altes Rezept',
        legacyIngredients: ['Reis'],
      ),
    ];
    await pump(tester, intolerances: const ['Laktose']);
    expect(find.byType(RecipeListTile), findsNWidgets(3));

    await tester.tap(find.byKey(CollectionScreen.fitToggleKey));
    await tester.pumpAndSettle();

    expect(tile('Reisbowl'), findsOneWidget);
    expect(tile('Milchreis'), findsNothing);
    expect(tile('Altes Rezept'), findsNothing);
  });

  testWidgets('Histamin line under the toggle', (tester) async {
    await pump(tester, intolerances: const ['Histamin']);

    expect(find.text('Passt zu mir'), findsOneWidget);
    expect(
      find.text('Histamin kann ich nicht prüfen, bitte schau da selbst.'),
      findsOneWidget,
    );
  });

  testWidgets('no selfCheck line without Histamin', (tester) async {
    await pump(tester, intolerances: const ['Laktose']);
    expect(find.textContaining('kann ich nicht prüfen'), findsNothing);
  });

  testWidgets('rules missing: no Passt-zu-mir toggle', (tester) async {
    repo.rules = null;
    await pump(tester, intolerances: const ['Laktose']);

    expect(find.byKey(CollectionScreen.fitToggleKey), findsNothing);
    expect(find.byType(RecipeListTile), findsOneWidget);
  });

  testWidgets('search finds titles and ingredients', (tester) async {
    repo.collection = [
      testRecipe(
        id: 'a',
        title: 'Reis mit Honig',
        ingredients: [testLine('Honig')],
      ),
      testRecipe(
        id: 'b',
        title: 'Haferbrei',
        ingredients: [testLine('Hafer', position: 0), testLine('Honig')],
      ),
      testRecipe(id: 'c', title: 'Suppe', ingredients: [testLine('Karotte')]),
    ];
    await pump(tester);

    await tester.enterText(find.byKey(CollectionScreen.searchKey), 'honig');
    await tester.pumpAndSettle();

    expect(tile('Reis mit Honig'), findsOneWidget);
    expect(tile('Haferbrei'), findsOneWidget);
    expect(tile('Suppe'), findsNothing);
  });

  group('search', () {
    setUp(() {
      repo.collection = [
        testRecipe(
          id: 'a',
          title: 'Möhrensuppe',
          ingredients: [testLine('Möhren')],
        ),
        testRecipe(
          id: 'b',
          title: 'Ofengemüse',
          ingredients: [testLine('Süßkartoffel')],
        ),
        const Recipe(
          id: 'c',
          title: 'Altes Rezept',
          mealTypes: [MealType.lunch],
          legacyIngredients: ['200 g Basmatireis'],
        ),
      ];
    });

    Future<void> search(WidgetTester tester, String query) async {
      await tester.enterText(find.byKey(CollectionScreen.searchKey), query);
      await tester.pumpAndSettle();
    }

    testWidgets('umlauts in any case', (tester) async {
      await pump(tester);

      await search(tester, 'MÖHREN');
      expect(tile('Möhrensuppe'), findsOneWidget);
      expect(find.byType(RecipeListTile), findsOneWidget);

      await search(tester, 'süß');
      expect(tile('Ofengemüse'), findsOneWidget);
      expect(find.byType(RecipeListTile), findsOneWidget);
    });

    testWidgets('spaces around the query are ignored; blank shows all', (
      tester,
    ) async {
      await pump(tester);

      await search(tester, '  ofen  ');
      expect(tile('Ofengemüse'), findsOneWidget);
      expect(find.byType(RecipeListTile), findsOneWidget);

      await search(tester, '   ');
      expect(find.byType(RecipeListTile), findsNWidgets(3));
    });

    testWidgets("an older recipe's text lines are searched", (tester) async {
      await pump(tester);

      await search(tester, 'basmati');
      expect(tile('Altes Rezept'), findsOneWidget);
      expect(find.byType(RecipeListTile), findsOneWidget);
    });

    testWidgets('scrolling the list puts the keyboard away', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(CollectionScreen.searchKey));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.drag(
        find.byType(RecipeListTile).first,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('the query stays in the field after scrolling it away', (
      tester,
    ) async {
      repo.collection = [
        for (var i = 0; i < 40; i++) testRecipe(id: 'r$i', title: 'Suppe $i'),
      ];
      await pump(tester);
      await search(tester, 'Suppe');

      // Far enough that the lazy list drops the field, then back.
      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(find.byKey(CollectionScreen.searchKey), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, 8000));
      await tester.pumpAndSettle();

      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(CollectionScreen.searchKey),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.text, 'Suppe');
      expect(find.byType(RecipeListTile), findsWidgets);
    });
  });

  testWidgets('count line: singular and plural', (tester) async {
    repo.collection = [testRecipe()];
    await pump(tester);
    expect(find.text('1 Rezept · für dich sortiert'), findsOneWidget);
  });

  testWidgets('count line with the vegan note', (tester) async {
    repo.collection = [
      testRecipe(id: 'a', title: 'A'),
      testRecipe(id: 'b', title: 'B'),
      testRecipe(id: 'c', title: 'C', dietTags: const {'vegetarisch'}),
    ];
    await pump(tester, diet: 'vegan');

    expect(
      find.text(
        '2 Rezepte · für dich sortiert · nur vegane, wie in deinem Profil',
      ),
      findsOneWidget,
    );
  });

  testWidgets('count line with the vegetarian note', (tester) async {
    repo.collection = [
      testRecipe(id: 'a', title: 'A'),
      testRecipe(id: 'c', title: 'C', dietTags: const {}),
    ];
    await pump(tester, diet: 'vegetarisch');

    expect(
      find.text(
        '1 Rezept · für dich sortiert · nur vegetarische, wie in deinem Profil',
      ),
      findsOneWidget,
    );
  });

  testWidgets('nothing found', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(CollectionScreen.searchKey), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text(CollectionScreen.empty), findsOneWidget);
    expect(find.byType(RecipeListTile), findsNothing);
  });

  testWidgets('a tile opens the recipe', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(RecipeListTile));
    await tester.pumpAndSettle();

    expect(find.text('page:/collection/recipe-1'), findsOneWidget);
  });

  testWidgets('error without data shows the error state and retries', (
    tester,
  ) async {
    repo.collectionError = Exception('down');
    await pump(tester);
    expect(find.byType(BbErrorState), findsOneWidget);
    expect(find.text('Rezepte konnten nicht geladen werden.'), findsOneWidget);

    repo.collectionError = null;
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();
    expect(find.byType(RecipeListTile), findsOneWidget);
  });

  testWidgets('fits 375x667 at text scale 1.3', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo.collection = [
      testRecipe(id: 'a', title: 'Ein sehr langer Rezepttitel mit Reis'),
      dinner('Milchreis', lines: [milch]),
    ];

    final errors = await collectFlutterErrors(
      () => pump(
        tester,
        intolerances: const ['Laktose', 'Histamin'],
        diet: 'vegan',
        textScale: 1.3,
      ),
    );

    expect(find.byType(RecipeListTile), findsWidgets);
    expect(verticalOverflows(errors), isEmpty);
  });
}
