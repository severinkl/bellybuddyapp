import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/screens/recipes/recipe_editor_screen.dart';

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
        child: MaterialApp(home: RecipeEditorScreen(recipeId: recipeId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('create mode', () {
    testWidgets('shows "Neues Rezept" title and empty form', (tester) async {
      await pumpEditor(tester);

      expect(find.text('Neues Rezept'), findsOneWidget);
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

      await pumpEditor(tester);

      // Enter a title
      await tester.enterText(find.byType(TextField).first, 'Eiersalat');
      await tester.pump();

      // Tap Speichern
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
  });

  group('edit mode', () {
    testWidgets('shows "Rezept bearbeiten" and prefills title', (tester) async {
      final recipe = testUserRecipe(
        id: 'rec-1',
        title: 'Linseneintopf',
        ingredients: ['Linsen', 'Tomaten'],
      );
      await pumpEditor(tester, recipeId: 'rec-1', recipes: [recipe]);

      expect(find.text('Rezept bearbeiten'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Linseneintopf'), findsOneWidget);
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

      // Clear and re-enter the title
      final titleField = find.widgetWithText(TextField, 'Linseneintopf');
      await tester.tap(titleField);
      await tester.pump();
      await tester.enterText(titleField, 'Rote Linsensuppe');
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
}
