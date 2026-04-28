import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/screens/recipes/recipe_editor_screen.dart';
import 'package:belly_buddy/services/user_recipe_service.dart';
import 'package:belly_buddy/widgets/common/editable_app_bar_title.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
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
          ),
        ).called(1);
      },
    );
  });
}
