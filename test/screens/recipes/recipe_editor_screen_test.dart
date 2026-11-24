import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/models/user_recipe.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/screens/recipes/recipe_editor_screen.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_steps_editor.dart';
import 'package:belly_buddy/services/recipes/recipe_copy.dart';
import 'package:belly_buddy/services/user_recipe_service.dart';
import 'package:belly_buddy/widgets/common/editable_app_bar_title.dart';
import 'package:belly_buddy/widgets/common/ingredient_search.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/layout_checks.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockUserRecipeRepository repo;
  late MockMealMediaRepository mediaRepo;

  setUp(() {
    repo = MockUserRecipeRepository();
    mediaRepo = MockMealMediaRepository();
  });

  Future<void> pumpEditor(
    WidgetTester tester, {
    String? recipeId,
    MealEntry? initialMeal,
    List<dynamic> recipes = const [],
  }) async {
    when(
      () => repo.fetchForUser(any()),
    ).thenAnswer((_) async => recipes.cast());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRecipeRepositoryProvider.overrideWithValue(repo),
          mealMediaRepositoryProvider.overrideWithValue(mediaRepo),
          ingredientRepositoryProvider.overrideWithValue(
            FakeIngredientRepository(),
          ),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: MaterialApp(
          home: RecipeEditorScreen(
            recipeId: recipeId,
            initialMeal: initialMeal,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('create mode', () {
    testWidgets('shows EditableAppBarTitle in create mode', (tester) async {
      await pumpEditor(tester);

      expect(find.byType(EditableAppBarTitle), findsOneWidget);
      expect(find.text('Speichern'), findsOneWidget);
    });

    testWidgets('fills title and saves, calling repo.create', (tester) async {
      final newRecipe = testUserRecipe(id: 'new-1', title: 'Eiersalat');
      when(
        () => repo.create(
          userId: any(named: 'userId'),
          title: any(named: 'title'),
          ingredients: any(named: 'ingredients'),
          imageUrl: any(named: 'imageUrl'),
          instructions: any(named: 'instructions'),
          ingredientAmounts: any(named: 'ingredientAmounts'),
          adaptedFromRecipeId: any(named: 'adaptedFromRecipeId'),
        ),
      ).thenAnswer((_) async => newRecipe);
      when(() => repo.fetchForUser(any())).thenAnswer((_) async => [newRecipe]);

      // Seed via initialMeal so the recipe has ingredients (Save is gated
      // on title + at least one ingredient). Then rename the title via the
      // AppBar editable title to exercise the create-and-save flow.
      await pumpEditor(
        tester,
        initialMeal: testMealEntry(
          title: 'Original',
          ingredients: const ['Eier'],
        ),
      );

      await tester.tap(find.byType(EditableAppBarTitle));
      await tester.pump();
      final appBarTextField = find.descendant(
        of: find.byType(EditableAppBarTitle),
        matching: find.byType(TextField),
      );
      await tester.enterText(appBarTextField, 'Eiersalat');
      await tester.pump();

      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      verify(
        () => repo.create(
          userId: testUserId,
          title: 'Eiersalat',
          ingredients: any(named: 'ingredients'),
          imageUrl: any(named: 'imageUrl'),
          instructions: any(named: 'instructions'),
          ingredientAmounts: any(named: 'ingredientAmounts'),
          adaptedFromRecipeId: any(named: 'adaptedFromRecipeId'),
        ),
      ).called(1);
    });

    testWidgets('save button is disabled when no ingredients are added', (
      tester,
    ) async {
      await pumpEditor(tester);

      // Type a title — but don't add an ingredient.
      final appBarTextField = find.descendant(
        of: find.byType(EditableAppBarTitle),
        matching: find.byType(TextField),
      );
      await tester.enterText(appBarTextField, 'Eiersalat');
      await tester.pump();

      // Speichern's BbButton wraps a button; verify onPressed is null by
      // tapping and confirming repo.create was never invoked.
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      verifyNever(
        () => repo.create(
          userId: any(named: 'userId'),
          title: any(named: 'title'),
          ingredients: any(named: 'ingredients'),
          imageUrl: any(named: 'imageUrl'),
          instructions: any(named: 'instructions'),
          ingredientAmounts: any(named: 'ingredientAmounts'),
          adaptedFromRecipeId: any(named: 'adaptedFromRecipeId'),
        ),
      );
    });

    testWidgets(
      'duplicate-title error surfaces a friendly SnackBar instead of the generic save-failure one',
      (tester) async {
        when(
          () => repo.create(
            userId: any(named: 'userId'),
            title: any(named: 'title'),
            ingredients: any(named: 'ingredients'),
            imageUrl: any(named: 'imageUrl'),
            instructions: any(named: 'instructions'),
            ingredientAmounts: any(named: 'ingredientAmounts'),
            adaptedFromRecipeId: any(named: 'adaptedFromRecipeId'),
          ),
        ).thenThrow(const DuplicateRecipeTitleException());

        await pumpEditor(
          tester,
          initialMeal: testMealEntry(
            title: 'Original',
            ingredients: const ['Eier'],
          ),
        );

        await tester.tap(find.byType(EditableAppBarTitle));
        await tester.pump();
        final appBarTextField = find.descendant(
          of: find.byType(EditableAppBarTitle),
          matching: find.byType(TextField),
        );
        await tester.enterText(appBarTextField, 'Eiersalat');
        await tester.pump();

        await tester.tap(find.text('Speichern'));
        await tester.pumpAndSettle();

        expect(
          find.text('Du hast bereits ein Rezept mit diesem Titel.'),
          findsOneWidget,
        );
        expect(
          find.text('Speichern fehlgeschlagen. Bitte erneut versuchen.'),
          findsNothing,
        );
      },
    );
  });

  group('edit mode', () {
    testWidgets('shows EditableAppBarTitle prefilled with recipe title', (
      tester,
    ) async {
      final recipe = testUserRecipe(
        id: 'rec-1',
        title: 'Linseneintopf',
        ingredients: ['Linsen', 'Tomaten'],
      );
      await pumpEditor(tester, recipeId: 'rec-1', recipes: [recipe]);

      // EditableAppBarTitle in display mode renders the title as a Text widget.
      expect(find.byType(EditableAppBarTitle), findsOneWidget);
      expect(find.text('Linseneintopf'), findsOneWidget);
    });

    testWidgets('saves updated title, calling repo.update', (tester) async {
      final recipe = testUserRecipe(
        id: 'rec-1',
        title: 'Linseneintopf',
        ingredients: ['Linsen'],
      );
      final updated = testUserRecipe(
        id: 'rec-1',
        title: 'Rote Linsensuppe',
        ingredients: ['Linsen'],
      );
      when(() => repo.fetchForUser(any())).thenAnswer((_) async => [recipe]);
      when(
        () => repo.update(
          id: any(named: 'id'),
          title: any(named: 'title'),
          ingredients: any(named: 'ingredients'),
          imageUrl: any(named: 'imageUrl'),
          instructions: any(named: 'instructions'),
          ingredientAmounts: any(named: 'ingredientAmounts'),
        ),
      ).thenAnswer((_) async => updated);

      await pumpEditor(tester, recipeId: 'rec-1', recipes: [recipe]);

      // Tap EditableAppBarTitle to enter edit mode, then update the title.
      await tester.tap(find.byType(EditableAppBarTitle));
      await tester.pump();
      final appBarTextField = find.descendant(
        of: find.byType(EditableAppBarTitle),
        matching: find.byType(TextField),
      );
      await tester.enterText(appBarTextField, 'Rote Linsensuppe');
      await tester.pump();

      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      verify(
        () => repo.update(
          id: 'rec-1',
          title: 'Rote Linsensuppe',
          ingredients: any(named: 'ingredients'),
          imageUrl: any(named: 'imageUrl'),
          instructions: any(named: 'instructions'),
          ingredientAmounts: any(named: 'ingredientAmounts'),
        ),
      ).called(1);
    });
  });

  group('create mode prefilled from initialMeal', () {
    testWidgets('renders title in display mode (not autofocused)', (
      tester,
    ) async {
      final meal = testMealEntry(title: 'Linseneintopf');
      await pumpEditor(tester, initialMeal: meal);

      expect(
        find.descendant(
          of: find.byType(EditableAppBarTitle),
          matching: find.text('Linseneintopf'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(EditableAppBarTitle),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
    });

    testWidgets('renders a chip per ingredient from the meal', (tester) async {
      final meal = testMealEntry(
        title: 'Linseneintopf',
        ingredients: const ['Linsen', 'Tomaten', 'Zwiebel'],
      );
      await pumpEditor(tester, initialMeal: meal);

      expect(find.widgetWithText(Chip, 'Linsen'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Tomaten'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Zwiebel'), findsOneWidget);
    });

    testWidgets(
      'tapping Speichern calls repo.create with the prefilled values',
      (tester) async {
        final meal = testMealEntry(
          title: 'Linseneintopf',
          ingredients: const ['Linsen', 'Tomaten'],
        );
        when(
          () => repo.create(
            userId: any(named: 'userId'),
            title: any(named: 'title'),
            ingredients: any(named: 'ingredients'),
            imageUrl: any(named: 'imageUrl'),
            instructions: any(named: 'instructions'),
            ingredientAmounts: any(named: 'ingredientAmounts'),
            adaptedFromRecipeId: any(named: 'adaptedFromRecipeId'),
          ),
        ).thenAnswer(
          (_) async => testUserRecipe(
            title: meal.title,
            ingredients: meal.ingredients,
            imageUrl: meal.imageUrl,
          ),
        );
        await pumpEditor(tester, initialMeal: meal);

        await tester.tap(find.text('Speichern'));
        await tester.pumpAndSettle();

        verify(
          () => repo.create(
            userId: testUserId,
            title: 'Linseneintopf',
            ingredients: const ['Linsen', 'Tomaten'],
            imageUrl: any(named: 'imageUrl'),
            instructions: any(named: 'instructions'),
            ingredientAmounts: any(named: 'ingredientAmounts'),
            adaptedFromRecipeId: any(named: 'adaptedFromRecipeId'),
          ),
        ).called(1);
      },
    );
  });

  group('steps and amounts', () {
    setUp(() {
      when(
        () => repo.create(
          userId: any(named: 'userId'),
          title: any(named: 'title'),
          ingredients: any(named: 'ingredients'),
          imageUrl: any(named: 'imageUrl'),
          instructions: any(named: 'instructions'),
          ingredientAmounts: any(named: 'ingredientAmounts'),
          adaptedFromRecipeId: any(named: 'adaptedFromRecipeId'),
        ),
      ).thenAnswer((_) async => testUserRecipe());
      when(
        () => repo.update(
          id: any(named: 'id'),
          title: any(named: 'title'),
          ingredients: any(named: 'ingredients'),
          imageUrl: any(named: 'imageUrl'),
          instructions: any(named: 'instructions'),
          ingredientAmounts: any(named: 'ingredientAmounts'),
        ),
      ).thenAnswer((_) async => testUserRecipe());
    });

    Future<void> tall(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> verifyUpdate(
      WidgetTester tester, {
      List<String>? instructions,
      List<String?>? amounts,
    }) async {
      final call = verify(
        () => repo.update(
          id: 'rec-1',
          title: any(named: 'title'),
          ingredients: any(named: 'ingredients'),
          imageUrl: any(named: 'imageUrl'),
          instructions: captureAny(named: 'instructions'),
          ingredientAmounts: captureAny(named: 'ingredientAmounts'),
        ),
      )..called(1);
      expect(call.captured, [instructions, amounts]);
    }

    Future<void> save(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Speichern'));
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
    }

    testWidgets('add and remove steps', (tester) async {
      await tall(tester);
      await pumpEditor(tester);

      await tester.tap(find.byKey(RecipeStepsEditor.addKey));
      await tester.pump();
      expect(find.byKey(RecipeStepsEditor.fieldKey(0)), findsOneWidget);
      await tester.tap(find.byKey(RecipeStepsEditor.removeKey(0)));
      await tester.pump();
      expect(find.byKey(RecipeStepsEditor.fieldKey(0)), findsNothing);
    });

    testWidgets('create sends the trimmed non-empty steps', (tester) async {
      await tall(tester);
      await pumpEditor(
        tester,
        initialMeal: testMealEntry(title: 'Reis', ingredients: const ['Reis']),
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(RecipeStepsEditor.addKey));
        await tester.pump();
      }
      await tester.enterText(
        find.byKey(RecipeStepsEditor.fieldKey(0)),
        '  Kochen. ',
      );
      await tester.enterText(
        find.byKey(RecipeStepsEditor.fieldKey(2)),
        'Essen',
      );
      await save(tester);

      verify(
        () => repo.create(
          userId: testUserId,
          title: 'Reis',
          ingredients: any(named: 'ingredients'),
          imageUrl: any(named: 'imageUrl'),
          instructions: const ['Kochen.', 'Essen'],
          ingredientAmounts: any(named: 'ingredientAmounts'),
          adaptedFromRecipeId: any(named: 'adaptedFromRecipeId'),
        ),
      ).called(1);
    });

    testWidgets('edit without touching the steps sends none', (tester) async {
      await tall(tester);
      final recipe = testUserRecipe(
        id: 'rec-1',
        instructions: const ['Kochen.', 'Essen.'],
      );
      await pumpEditor(tester, recipeId: 'rec-1', recipes: [recipe]);
      expect(find.text('Kochen.'), findsOneWidget);

      await save(tester);

      await verifyUpdate(tester);
    });

    testWidgets('edited steps are sent', (tester) async {
      await tall(tester);
      final recipe = testUserRecipe(
        id: 'rec-1',
        instructions: const ['Kochen.'],
      );
      await pumpEditor(tester, recipeId: 'rec-1', recipes: [recipe]);

      await tester.enterText(
        find.byKey(RecipeStepsEditor.fieldKey(0)),
        'Anbraten.',
      );
      await save(tester);

      await verifyUpdate(tester, instructions: const ['Anbraten.']);
    });

    testWidgets("removing an ingredient keeps the others' amounts", (
      tester,
    ) async {
      await tall(tester);
      final recipe = testUserRecipe(
        id: 'rec-1',
        ingredients: const ['Knoblauchöl', 'Reis', 'Salz'],
        ingredientAmounts: const ['2 EL', '200 g', null],
      );
      await pumpEditor(tester, recipeId: 'rec-1', recipes: [recipe]);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(Chip, 'Reis'),
          matching: find.byIcon(Icons.cancel),
        ),
      );
      await tester.pump();
      await save(tester);

      await verifyUpdate(tester, amounts: const ['2 EL', null]);
    });

    testWidgets('a re-added ingredient comes back without its amount', (
      tester,
    ) async {
      await tall(tester);
      final recipe = testUserRecipe(
        id: 'rec-1',
        ingredients: const ['Knoblauchöl', 'Reis'],
        ingredientAmounts: const ['2 EL', '200 g'],
      );
      await pumpEditor(tester, recipeId: 'rec-1', recipes: [recipe]);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(Chip, 'Reis'),
          matching: find.byIcon(Icons.cancel),
        ),
      );
      await tester.pump();
      tester
          .widget<IngredientSearch>(find.byType(IngredientSearch))
          .onAdd('Reis');
      await tester.pump();
      expect(find.widgetWithText(Chip, 'Reis'), findsOneWidget);
      await save(tester);

      // „Reis" is a new line now: the 200 g were for the one taken out.
      await verifyUpdate(tester, amounts: const ['2 EL', null]);
    });

    testWidgets('clearing every step sends none left', (tester) async {
      await tall(tester);
      final recipe = testUserRecipe(
        id: 'rec-1',
        instructions: const ['Kochen.', 'Essen.'],
      );
      await pumpEditor(tester, recipeId: 'rec-1', recipes: [recipe]);

      await tester.tap(find.byKey(RecipeStepsEditor.removeKey(1)));
      await tester.pump();
      await tester.enterText(find.byKey(RecipeStepsEditor.fieldKey(0)), '  ');
      await save(tester);

      await verifyUpdate(tester, instructions: const []);
    });

    testWidgets('steps typed before the recipe loads give way to its steps', (
      tester,
    ) async {
      await tall(tester);
      final recipe = testUserRecipe(
        id: 'rec-1',
        instructions: const ['Kochen.'],
      );
      final load = Completer<List<UserRecipe>>();
      when(() => repo.fetchForUser(any())).thenAnswer((_) => load.future);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRecipeRepositoryProvider.overrideWithValue(repo),
            mealMediaRepositoryProvider.overrideWithValue(mediaRepo),
            currentUserIdProvider.overrideWithValue(testUserId),
          ],
          child: const MaterialApp(home: RecipeEditorScreen(recipeId: 'rec-1')),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(RecipeStepsEditor.addKey));
      await tester.pump();
      await tester.enterText(find.byKey(RecipeStepsEditor.fieldKey(0)), 'Neu');

      load.complete([recipe]);
      await tester.pumpAndSettle();

      // The form shows the recipe as saved, and saves what it shows.
      expect(find.text('Kochen.'), findsOneWidget);
      expect(find.text('Neu'), findsNothing);
      await save(tester);
      await verifyUpdate(tester);
    });

    testWidgets('a template sends no amounts', (tester) async {
      await tall(tester);
      final recipe = testUserRecipe(id: 'rec-1');
      await pumpEditor(tester, recipeId: 'rec-1', recipes: [recipe]);

      await save(tester);

      await verifyUpdate(tester);
    });

    group('a backend that keeps no steps', () {
      /// The editor pushed on a page that stays when it pops.
      Future<void> pushEditor(WidgetTester tester, {String? recipeId}) async {
        await tall(tester);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('page:home')),
            ),
            GoRoute(
              path: '/edit',
              builder: (_, _) => RecipeEditorScreen(
                recipeId: recipeId,
                initialMeal: recipeId == null
                    ? testMealEntry(title: 'Reis', ingredients: const ['Reis'])
                    : null,
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userRecipeRepositoryProvider.overrideWithValue(repo),
              mealMediaRepositoryProvider.overrideWithValue(mediaRepo),
              ingredientRepositoryProvider.overrideWithValue(
                FakeIngredientRepository(),
              ),
              currentUserIdProvider.overrideWithValue(testUserId),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        unawaited(router.push('/edit'));
        await tester.pumpAndSettle();
      }

      Future<void> typeStep(WidgetTester tester, String text) async {
        if (find.byKey(RecipeStepsEditor.fieldKey(0)).evaluate().isEmpty) {
          await tester.tap(find.byKey(RecipeStepsEditor.addKey));
          await tester.pump();
        }
        await tester.enterText(find.byKey(RecipeStepsEditor.fieldKey(0)), text);
      }

      testWidgets('create: saved, and the steps said to be left out', (
        tester,
      ) async {
        when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
        await pushEditor(tester);
        await typeStep(tester, 'Kochen.');
        await save(tester);

        expect(find.text('page:home'), findsOneWidget);
        expect(find.text(RecipeCopy.stepsNotSaved), findsOneWidget);
      });

      testWidgets('update: saved, and the steps said to be left out', (
        tester,
      ) async {
        final recipe = testUserRecipe(id: 'rec-1');
        when(() => repo.fetchForUser(any())).thenAnswer((_) async => [recipe]);
        await pushEditor(tester, recipeId: 'rec-1');
        await typeStep(tester, 'Kochen.');
        await save(tester);

        expect(find.text('page:home'), findsOneWidget);
        expect(find.text(RecipeCopy.stepsNotSaved), findsOneWidget);
      });

      testWidgets('steps kept: nothing said', (tester) async {
        when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
        when(
          () => repo.create(
            userId: any(named: 'userId'),
            title: any(named: 'title'),
            ingredients: any(named: 'ingredients'),
            imageUrl: any(named: 'imageUrl'),
            instructions: any(named: 'instructions'),
            ingredientAmounts: any(named: 'ingredientAmounts'),
            adaptedFromRecipeId: any(named: 'adaptedFromRecipeId'),
          ),
        ).thenAnswer(
          (_) async => testUserRecipe(instructions: const ['Kochen.']),
        );
        await pushEditor(tester);
        await typeStep(tester, 'Kochen.');
        await save(tester);

        expect(find.text('page:home'), findsOneWidget);
        expect(find.text(RecipeCopy.stepsNotSaved), findsNothing);
      });
    });

    testWidgets('too long: a message, no save', (tester) async {
      await tall(tester);
      await pumpEditor(
        tester,
        initialMeal: testMealEntry(title: 'Reis', ingredients: const ['Reis']),
      );
      await tester.tap(find.byKey(RecipeStepsEditor.addKey));
      await tester.pump();
      await tester.enterText(
        find.byKey(RecipeStepsEditor.fieldKey(0)),
        'x' * (AppConstants.recipeStepsMaxChars + 1),
      );
      await save(tester);

      expect(
        find.text('Die Zubereitung ist zu lang. Bitte kürze sie.'),
        findsOneWidget,
      );
      verifyNever(
        () => repo.create(
          userId: any(named: 'userId'),
          title: any(named: 'title'),
          ingredients: any(named: 'ingredients'),
          imageUrl: any(named: 'imageUrl'),
          instructions: any(named: 'instructions'),
          ingredientAmounts: any(named: 'ingredientAmounts'),
          adaptedFromRecipeId: any(named: 'adaptedFromRecipeId'),
        ),
      );
    });

    testWidgets('50 steps: add is disabled', (tester) async {
      await tall(tester);
      final recipe = testUserRecipe(
        id: 'rec-1',
        instructions: List.filled(AppConstants.recipeStepsMax, 'x'),
      );
      await pumpEditor(tester, recipeId: 'rec-1', recipes: [recipe]);

      await tester.ensureVisible(find.byKey(RecipeStepsEditor.addKey));
      expect(
        tester
            .widget<TextButton>(find.byKey(RecipeStepsEditor.addKey))
            .onPressed,
        isNull,
      );
    });

    testWidgets('fits 375x667 at text scale 1.3 with 3 steps', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final recipe = testUserRecipe(
        id: 'rec-1',
        instructions: const ['Eins.', 'Zwei.', 'Drei.'],
      );
      when(() => repo.fetchForUser(any())).thenAnswer((_) async => [recipe]);
      final errors = await collectFlutterErrors(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userRecipeRepositoryProvider.overrideWithValue(repo),
              mealMediaRepositoryProvider.overrideWithValue(mediaRepo),
              currentUserIdProvider.overrideWithValue(testUserId),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: const RecipeEditorScreen(recipeId: 'rec-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });
      expect(verticalOverflows(errors), isEmpty);
      expect(errors, isEmpty);
    });
  });
}
