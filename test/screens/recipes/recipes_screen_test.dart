import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/recipe_search_provider.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/screens/recipes/my_recipes_tab.dart';
import 'package:belly_buddy/screens/recipes/recipes_screen.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';
import '../../helpers/riverpod_helpers.dart';

void main() {
  late MockUserRecipeRepository repo;

  setUp(() {
    repo = MockUserRecipeRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRecipeRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: const MaterialApp(home: RecipesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows my recipes directly', (tester) async {
    await pumpScreen(tester);
    expect(find.byType(MyRecipesTab), findsOneWidget);
    expect(find.text('Noch keine Rezepte'), findsOneWidget); // empty-state body
  });

  testWidgets('no Inspiration', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Inspiration'), findsNothing);
    expect(find.text('Rezepte kommen bald!'), findsNothing);
  });

  testWidgets('closing the screen clears the recipe search', (tester) async {
    when(
      () => repo.fetchForUser(any()),
    ).thenAnswer((_) async => [testUserRecipe()]);
    when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);
    final container = createContainer(
      overrides: [
        userRecipeRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue(testUserId),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RecipesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(container.read(recipeSearchProvider.notifier).activeQuery, 'zzz');
    expect(find.text('Keine Treffer'), findsOneWidget);
    // The search never filters the user's recipes.
    expect(container.read(userRecipesProvider).value, hasLength(1));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(recipeSearchProvider.exists), isFalse);
    expect(container.read(userRecipesProvider).value, hasLength(1));
  });

  testWidgets('the + opens the add-recipe chooser', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Rezept hinzufügen'), findsOneWidget);
  });
}
