import 'package:belly_buddy/models/fodmap_flags.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/screens/dashboard/dashboard_screen.dart';
import 'package:belly_buddy/screens/discover/discover_screen.dart';
import 'package:belly_buddy/screens/discover/widgets/discover_recipes_section.dart';
import 'package:belly_buddy/screens/recipes/adapt_recipe_screen.dart';
import 'package:belly_buddy/screens/recipes/collection_recipe_screen.dart';
import 'package:belly_buddy/screens/recipes/collection_screen.dart';
import 'package:belly_buddy/screens/recipes/recipe_detail_screen.dart';
import 'package:belly_buddy/screens/recipes/recipe_editor_screen.dart';
import 'package:belly_buddy/screens/recipes/widgets/ingredient_line_view.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_steps.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_steps_editor.dart';
import 'package:belly_buddy/screens/trackers/meal/meal_tracker_screen.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:belly_buddy/widgets/common/bb_success_overlay.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import '../test/helpers/fakes.dart';
import '../test/helpers/fixtures.dart';
import '../test/helpers/widget_tester_helpers.dart';
import 'helpers/test_app.dart';

const _reisBowl = 'Reis-Bowl';
const _porridge = 'Honig-Porridge';
const _curry = 'Hähnchen-Curry';

/// [testAdaptedRecipe]'s title: Honig swapped for Ahornsirup.
const _adapted = 'Porridge mit Ahornsirup';

/// The collection: „Reis-Bowl" fits a Fruktose user, „Honig-Porridge" has
/// Honig (Fruktose) kritisch, and „Hähnchen-Curry" carries no diet tag, so
/// a vegetarian never sees it.
FakeRecipeRepository _collection() => FakeRecipeRepository()
  ..collection = [
    testRecipe(
      id: 'reis-bowl',
      title: _reisBowl,
      mealTypes: const [MealType.lunch],
      ingredients: [
        testLine('Reis', amount: '150 g'),
        testLine('Karotte', position: 1, amount: '1'),
      ],
      instructions: const ['Reis kochen.', 'Karotte dazugeben.'],
    ),
    testRecipe(
      id: 'honig-porridge',
      title: _porridge,
      mealTypes: const [MealType.breakfast],
      dietTags: const {'vegetarisch'},
      ingredients: [
        testLine('Haferflocken', amount: '50 g'),
        testLine('Haferdrink', position: 1, amount: '200 ml'),
        testLine(
          'Honig',
          position: 2,
          amount: '1 EL',
          fodmaps: const FodmapFlags(fructose: true),
        ),
      ],
      instructions: const [
        'Haferflocken im Haferdrink aufkochen.',
        'Mit Honig süßen.',
      ],
    ),
    testRecipe(
      id: 'haehnchen-curry',
      title: _curry,
      mealTypes: const [MealType.dinner],
      dietTags: const {},
      ingredients: [testLine('Hähnchen'), testLine('Reis', position: 1)],
    ),
  ];

/// The app for a vegetarian with Fruktose, over [recipeRepo].
ProviderScope _app({
  required FakeRecipeRepository recipeRepo,
  FakeUserRecipeRepository? userRecipeRepo,
  FakeEntryRepository? entryRepo,
}) => buildTestApp(
  // This profile instead of the default one; the Buddy is onboarded.
  seedProfile: false,
  seedBuddy: true,
  profileRepo: FakeProfileRepository()
    ..seedProfile(
      testUserProfile(intolerances: const ['Fruktose'], diet: 'vegetarisch'),
    ),
  recipeRepo: recipeRepo,
  userRecipeRepo: userRecipeRepo,
  entryRepo: entryRepo,
);

Finder _inForYou(Finder f) => find.descendant(
  of: find.byKey(DiscoverRecipesSection.forYouKey),
  matching: f,
);

Finder _inMine(Finder f) => find.descendant(
  of: find.byKey(DiscoverRecipesSection.mineKey),
  matching: f,
);

Finder _in(Type screen, Finder f) =>
    find.descendant(of: find.byType(screen), matching: f);

Future<void> _openDiscover(WidgetTester tester) async {
  await tester.tapVisible(find.byKey(BbBottomNav.navDiscoverKey));
  expect(find.byType(DiscoverScreen), findsOneWidget);
}

/// The app bar's back arrow of [screen].
Future<void> _back(WidgetTester tester, Type screen) =>
    tester.tapVisible(_in(screen, find.byTooltip('Zurück')));

/// Takes the SnackBar away, as its timer would, so it covers nothing.
Future<void> _dismissSnackBar(WidgetTester tester) async {
  ScaffoldMessenger.of(
    tester.element(find.byType(SnackBar).first),
  ).removeCurrentSnackBar();
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(setNotificationModalShown);

  testWidgets('Für dich → the list → „Passt zu mir" → a kritisch recipe '
      '→ Für mich anpassen → saved, „Angepasst" in Meine Rezepte', (
    tester,
  ) async {
    final recipeRepo = _collection();
    final userRecipes = FakeUserRecipeRepository();
    await tester.pumpWidget(
      _app(recipeRepo: recipeRepo, userRecipeRepo: userRecipes),
    );
    await tester.pumpAndSettle();
    await _openDiscover(tester);

    expect(_inForYou(find.text(_reisBowl)), findsOneWidget);
    expect(_inForYou(find.text(_porridge)), findsOneWidget);
    expect(_inForYou(find.text(_curry)), findsNothing);
    // Meine Rezepte is empty: the header's is the only „Alle ›".
    final all = find.descendant(
      of: find.byKey(DiscoverScreen.recipesKey),
      matching: find.text('Alle ›'),
    );
    expect(all, findsOneWidget);
    await tester.tapVisible(all);

    // The list lives in the Entdecken tab: the bar stays.
    expect(find.byType(CollectionScreen), findsOneWidget);
    expect(find.byType(BbBottomNav).hitTestable(), findsOneWidget);
    expect(
      find.text(
        '2 Rezepte · für dich sortiert · nur vegetarische, wie in deinem '
        'Profil',
      ),
      findsOneWidget,
    );
    expect(_in(CollectionScreen, find.text(_reisBowl)), findsOneWidget);
    expect(_in(CollectionScreen, find.text(_porridge)), findsOneWidget);
    expect(_in(CollectionScreen, find.text(_curry)), findsNothing);

    await tester.tapVisible(find.byKey(CollectionScreen.fitToggleKey));
    expect(_in(CollectionScreen, find.text(_reisBowl)), findsOneWidget);
    expect(_in(CollectionScreen, find.text(_porridge)), findsNothing);
    expect(
      find.text(
        '1 Rezept · für dich sortiert · nur vegetarische, wie in deinem '
        'Profil',
      ),
      findsOneWidget,
    );

    await tester.tapVisible(find.byKey(CollectionScreen.fitToggleKey));
    await tester.tapVisible(_in(CollectionScreen, find.text(_porridge)));

    expect(find.byType(CollectionRecipeScreen), findsOneWidget);
    expect(find.text('Honig — für dich kritisch'), findsOneWidget);
    // Nothing is sent before the user asks.
    expect(recipeRepo.adaptCalls, 0);

    await tester.tapVisible(find.byKey(CollectionRecipeScreen.adaptKey));

    expect(find.byType(AdaptRecipeScreen), findsOneWidget);
    expect(recipeRepo.adaptCalls, 1);
    expect(find.text(_adapted), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(IngredientLineView),
        matching: find.textContaining('getauscht'),
      ),
      findsOneWidget,
    );
    expect(find.text(AdaptRecipeScreen.allChecked), findsOneWidget);

    final save = find.byKey(AdaptRecipeScreen.saveKey);
    expect(
      find.descendant(
        of: save,
        matching: find.text('In Meine Rezepte speichern'),
      ),
      findsOneWidget,
    );
    await tester.tapVisible(save);
    expect(
      find.descendant(
        of: save,
        matching: find.text('In Meine Rezepte gespeichert'),
      ),
      findsOneWidget,
    );
    final saved = (await userRecipes.fetchForUser(testUserId)).single;
    expect(saved.title, _adapted);
    expect(saved.adaptedFromRecipeId, 'honig-porridge');

    // Back: the adapt screen, the recipe, the list.
    await _back(tester, AdaptRecipeScreen);
    await _back(tester, CollectionRecipeScreen);
    await tester.tapVisible(_in(CollectionScreen, find.byType(BackButton)));

    expect(find.byType(DiscoverScreen), findsOneWidget);
    expect(_inMine(find.text(_adapted)), findsOneWidget);
    expect(_inMine(find.text('Angepasst')), findsOneWidget);
  });

  testWidgets('Merken: the heart card in Meine Rezepte, gone once un-merk’d', (
    tester,
  ) async {
    final recipeRepo = _collection();
    await tester.pumpWidget(_app(recipeRepo: recipeRepo));
    await tester.pumpAndSettle();
    await _openDiscover(tester);

    await tester.tapVisible(_inForYou(find.text(_reisBowl)));
    expect(find.byType(CollectionRecipeScreen), findsOneWidget);
    final merken = find.byKey(CollectionRecipeScreen.saveKey);
    expect(
      find.descendant(of: merken, matching: find.text('Merken')),
      findsOneWidget,
    );

    await tester.tapVisible(merken);
    expect(
      find.descendant(of: merken, matching: find.text('Gemerkt')),
      findsOneWidget,
    );
    expect(find.text(CollectionRecipeScreen.saved), findsOneWidget);
    expect(recipeRepo.added, ['reis-bowl']);
    await _dismissSnackBar(tester);

    await _back(tester, CollectionRecipeScreen);
    expect(find.byType(DiscoverScreen), findsOneWidget);
    expect(_inMine(find.text(_reisBowl)), findsOneWidget);
    expect(_inMine(find.text('Gemerkt')), findsOneWidget);
    expect(_inMine(find.byIcon(Icons.favorite)), findsOneWidget);

    await tester.tapVisible(_inMine(find.text(_reisBowl)));
    expect(
      find.descendant(of: merken, matching: find.text('Gemerkt')),
      findsOneWidget,
    );
    await tester.tapVisible(merken);
    expect(
      find.descendant(of: merken, matching: find.text('Merken')),
      findsOneWidget,
    );
    expect(find.text(CollectionRecipeScreen.unsaved), findsOneWidget);
    expect(recipeRepo.removed, ['reis-bowl']);
    await _dismissSnackBar(tester);

    await _back(tester, CollectionRecipeScreen);
    expect(find.byType(DiscoverScreen), findsOneWidget);
    expect(_inMine(find.text(_reisBowl)), findsNothing);
    expect(_inMine(find.text('Noch keine Rezepte.')), findsOneWidget);
  });

  testWidgets('Als Essen eintragen: the tracker with the recipe\'s '
      'ingredients → saved → Home', (tester) async {
    final entryRepo = FakeEntryRepository();
    await tester.pumpWidget(
      _app(recipeRepo: _collection(), entryRepo: entryRepo),
    );
    await tester.pumpAndSettle();
    await _openDiscover(tester);

    await tester.tapVisible(_inForYou(find.text(_reisBowl)));
    await tester.tapVisible(find.byKey(CollectionRecipeScreen.logKey));

    expect(find.byType(MealTrackerScreen), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Reis'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Karotte'), findsOneWidget);

    await tester.tapVisible(_in(MealTrackerScreen, find.text('Speichern')));
    expect(find.byType(BbSuccessOverlay), findsOneWidget);

    // Tap the message: a tap in the middle would poke the Buddy.
    await tester.tap(find.text('Mahlzeit gespeichert!'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);

    final meal = entryRepo.addedMeals.single;
    expect(meal.title, _reisBowl);
    expect(meal.ingredients, ['Reis', 'Karotte']);
  });

  testWidgets('steps: an own recipe → „Schritte hinzufügen" → one step '
      '→ the detail shows it', (tester) async {
    const step = 'Gemüse schneiden und anbraten.';
    final userRecipes = FakeUserRecipeRepository(
      seed: [
        testUserRecipe(
          id: 'r1',
          userId: testUserId,
          title: 'Gemüsepfanne',
          ingredients: const ['Zucchini', 'Paprika'],
        ),
      ],
    );
    await tester.pumpWidget(
      _app(recipeRepo: _collection(), userRecipeRepo: userRecipes),
    );
    await tester.pumpAndSettle();
    await _openDiscover(tester);

    await tester.tapVisible(_inMine(find.text('Gemüsepfanne')));
    expect(find.byType(RecipeDetailScreen), findsOneWidget);
    expect(find.text('Noch keine Schritte.'), findsOneWidget);

    await tester.tapVisible(find.text('Schritte hinzufügen'));
    expect(find.byType(RecipeEditorScreen), findsOneWidget);

    await tester.tapVisible(find.byKey(RecipeStepsEditor.addKey));
    await tester.enterText(find.byKey(RecipeStepsEditor.fieldKey(0)), step);
    await tester.pumpAndSettle();
    await tester.tapVisible(_in(RecipeEditorScreen, find.text('Speichern')));

    expect(find.byType(RecipeEditorScreen), findsNothing);
    expect(find.byType(RecipeDetailScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(RecipeSteps.numberKey(0)),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(find.text(step), findsOneWidget);
    expect(find.text('Noch keine Schritte.'), findsNothing);
    final stored = (await userRecipes.fetchForUser(testUserId)).single;
    expect(stored.instructions, [step]);
  });
}
