import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:belly_buddy/screens/dashboard/dashboard_screen.dart';
import 'package:belly_buddy/screens/dashboard/widgets/feature_card.dart';
import 'package:belly_buddy/screens/recipes/recipes_screen.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:belly_buddy/widgets/common/bb_success_overlay.dart';
import 'package:belly_buddy/widgets/common/editable_app_bar_title.dart';
import 'package:belly_buddy/widgets/common/ingredient_search.dart';

import '../test/helpers/fakes.dart';
import 'helpers/test_app.dart';

Future<void> _openRecipesTab(WidgetTester tester) async {
  final rezepteCard = find.widgetWithText(FeatureCard, 'Rezepte');
  await tester.ensureVisible(rezepteCard);
  await tester.pumpAndSettle();
  await tester.tap(rezepteCard);
  await tester.pumpAndSettle();
}

Future<void> _openMealTracker(WidgetTester tester) async {
  await tester.tap(find.byKey(BbBottomNav.centerButtonKey));
  await tester.pumpAndSettle();
}

Future<void> _enterTitleAndIngredient(
  WidgetTester tester, {
  required String title,
  required String ingredient,
}) async {
  final titleField = find.descendant(
    of: find.byType(EditableAppBarTitle),
    matching: find.byType(TextField),
  );
  await tester.enterText(titleField, title);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();

  await tester.tap(find.text('+ Hinzufügen'));
  await tester.pumpAndSettle();
  final ingredientField = find.descendant(
    of: find.byType(IngredientSearch),
    matching: find.byType(TextField),
  );
  await tester.enterText(ingredientField, ingredient);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setNotificationModalShown();
  });

  testWidgets(
    'tapping the Rezepte feature card opens the recipes screen with the empty state',
    (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final rezepteCard = find.widgetWithText(FeatureCard, 'Rezepte');
      expect(rezepteCard, findsOneWidget);

      await tester.ensureVisible(rezepteCard);
      await tester.pumpAndSettle();
      await tester.tap(rezepteCard);
      await tester.pumpAndSettle();

      expect(find.byType(RecipesScreen), findsOneWidget);
      expect(find.text('Noch keine Rezepte'), findsOneWidget);
      expect(find.text('Erstes Rezept erstellen'), findsOneWidget);
    },
  );

  testWidgets(
    'recipes screen lists pre-seeded user recipes from the repository',
    (tester) async {
      final repo = FakeUserRecipeRepository(
        seed: [
          testUserRecipe(id: 'r1', title: 'Curry mit Reis'),
          testUserRecipe(id: 'r2', title: 'Pasta Bolognese'),
        ],
      );

      await tester.pumpWidget(buildTestApp(userRecipeRepo: repo));
      await tester.pumpAndSettle();

      final rezepteCard = find.widgetWithText(FeatureCard, 'Rezepte');
      await tester.ensureVisible(rezepteCard);
      await tester.pumpAndSettle();
      await tester.tap(rezepteCard);
      await tester.pumpAndSettle();

      expect(find.byType(RecipesScreen), findsOneWidget);
      expect(find.text('Curry mit Reis'), findsOneWidget);
      expect(find.text('Pasta Bolognese'), findsOneWidget);
      // Empty-state CTA should NOT be present when the user has recipes.
      expect(find.text('Erstes Rezept erstellen'), findsNothing);
    },
  );

  testWidgets('create recipe from scratch: chooser → editor → save → grid', (
    tester,
  ) async {
    final repo = FakeUserRecipeRepository();
    await tester.pumpWidget(buildTestApp(userRecipeRepo: repo));
    await tester.pumpAndSettle();

    await _openRecipesTab(tester);
    expect(find.text('Noch keine Rezepte'), findsOneWidget);

    await tester.tap(find.text('Erstes Rezept erstellen'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Neu erstellen'));
    await tester.pumpAndSettle();

    await _enterTitleAndIngredient(
      tester,
      title: 'Eiersalat',
      ingredient: 'Eier',
    );

    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    // Back on the recipes grid with the new recipe.
    expect(find.byType(RecipesScreen), findsOneWidget);
    expect(find.text('Eiersalat'), findsOneWidget);

    // Round-trip via the fake repo.
    final stored = await repo.fetchForUser('test-user-id');
    expect(stored.map((r) => r.title), contains('Eiersalat'));
    expect(stored.first.ingredients, contains('Eier'));
  });

  testWidgets('prefill meal tracker from a recipe → save → land on dashboard', (
    tester,
  ) async {
    final recipeRepo = FakeUserRecipeRepository(
      seed: [
        testUserRecipe(
          id: 'r1',
          title: 'Curry mit Reis',
          ingredients: ['Reis', 'Curry'],
        ),
      ],
    );
    final entryRepo = FakeEntryRepository();

    await tester.pumpWidget(
      buildTestApp(userRecipeRepo: recipeRepo, entryRepo: entryRepo),
    );
    await tester.pumpAndSettle();

    await _openMealTracker(tester);

    // Empty-state image card has the third "Rezept" picker button when
    // userRecipesProvider has resolved with at least one recipe.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rezept'));
    await tester.pumpAndSettle();

    // Recipe selector sheet — tap the seeded recipe row.
    await tester.tap(find.text('Curry mit Reis'));
    await tester.pumpAndSettle();

    // Form is prefilled.
    expect(find.widgetWithText(Chip, 'Reis'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Curry'), findsOneWidget);

    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    // Success overlay — tap to dismiss. Because initialRecipe != null,
    // the dismiss handler is context.go(/dashboard).
    expect(find.byType(BbSuccessOverlay), findsOneWidget);
    await tester.tap(find.byType(BbSuccessOverlay));
    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);

    // Round-trip: the meal landed in the entries repo.
    expect(entryRepo.addedMeals, hasLength(1));
    final saved = entryRepo.addedMeals.single;
    expect(saved.title, 'Curry mit Reis');
    expect(saved.ingredients, containsAll(['Reis', 'Curry']));
  });

  testWidgets('save-as-recipe from the meal tracker success screen', (
    tester,
  ) async {
    final recipeRepo = FakeUserRecipeRepository();
    await tester.pumpWidget(buildTestApp(userRecipeRepo: recipeRepo));
    await tester.pumpAndSettle();

    await _openMealTracker(tester);

    await _enterTitleAndIngredient(
      tester,
      title: 'Pasta Bolognese',
      ingredient: 'Nudeln',
    );

    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    // Success overlay shows the "Als Rezept speichern" callout.
    expect(find.text('Als Rezept speichern'), findsOneWidget);
    await tester.tap(find.text('Als Rezept speichern'));
    await tester.pumpAndSettle();

    // Button label flips to "Als Rezept gespeichert" + check icon.
    expect(find.text('Als Rezept gespeichert'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    // Round-trip via the fake repo.
    final stored = await recipeRepo.fetchForUser('test-user-id');
    expect(stored.map((r) => r.title), contains('Pasta Bolognese'));
    expect(stored.first.ingredients, contains('Nudeln'));
  });
}
