import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/screens/recipes/my_recipes_tab.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_list_tile.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockUserRecipeRepository repo;

  setUp(() {
    repo = MockUserRecipeRepository();
  });

  Future<void> pumpTab(WidgetTester tester, {required List recipes}) async {
    when(
      () => repo.fetchForUser(any()),
    ).thenAnswer((_) async => recipes.cast());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRecipeRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: const MaterialApp(home: Scaffold(body: MyRecipesTab())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows empty state CTA when no recipes', (tester) async {
    await pumpTab(tester, recipes: const []);

    expect(find.text('Noch keine Rezepte'), findsOneWidget);
    expect(find.text('Erstes Rezept erstellen'), findsOneWidget);
    expect(find.byType(RecipeListTile), findsNothing);
  });

  testWidgets('lists recipes when present', (tester) async {
    final recipes = [
      testUserRecipe(id: 'a', title: 'Curry'),
      testUserRecipe(id: 'b', title: 'Pasta'),
    ];
    await pumpTab(tester, recipes: recipes);

    expect(find.byType(RecipeListTile), findsNWidgets(2));
    expect(find.text('Curry'), findsOneWidget);
    expect(find.text('Pasta'), findsOneWidget);
    expect(find.text('Noch keine Rezepte'), findsNothing);
  });
}
