import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/screens/recipes/recipe_detail_screen.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockUserRecipeRepository repo;

  setUp(() {
    repo = MockUserRecipeRepository();
  });

  Future<void> pumpDetail(
    WidgetTester tester, {
    required List recipes,
    required String id,
  }) async {
    when(
      () => repo.fetchForUser(any()),
    ).thenAnswer((_) async => recipes.cast());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRecipeRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: MaterialApp(home: RecipeDetailScreen(recipeId: id)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders title + ingredients', (tester) async {
    final recipe = testUserRecipe(
      id: 'rec-1',
      title: 'Linseneintopf',
      ingredients: const ['Linsen', 'Tomaten'],
    );
    await pumpDetail(tester, recipes: [recipe], id: 'rec-1');

    // Title appears in AppBar and in the scrollable body (spec requirement)
    expect(find.text('Linseneintopf'), findsAtLeastNWidgets(2));
    expect(find.text('Linsen'), findsOneWidget);
    expect(find.text('Mahlzeit jetzt tracken'), findsOneWidget);
  });

  testWidgets('shows not-found when recipe id is missing', (tester) async {
    await pumpDetail(tester, recipes: [], id: 'missing');

    expect(find.text('Rezept nicht gefunden'), findsOneWidget);
  });
}
