import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/recipe_search_provider.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipes_search_field.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/mocks.dart';
import '../../../helpers/semantics_checks.dart';

void main() {
  late MockUserRecipeRepository repo;

  setUp(() {
    repo = MockUserRecipeRepository();
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
    when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRecipeRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: RecipesSearchField(host: RecipeSearchHost.myRecipes),
          ),
        ),
      ),
    );
  }

  testWidgets('typing pushes the query to the provider after debounce', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'curry');
    await tester.pump(const Duration(milliseconds: 350));

    verify(() => repo.searchForUser(testUserId, 'curry')).called(1);
  });

  testWidgets('clear icon appears when text is non-empty and clears on tap', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'curry');
    await tester.pump();

    final clear = find.byIcon(Icons.clear);
    expect(clear, findsOneWidget);

    await tester.tap(clear);
    await tester.pump();
    expect(find.text('curry'), findsNothing);
  });

  testWidgets('while empty, „Rezept suchen" is read once, with an example', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    expectSearchFieldReadOnce(
      tester,
      name: 'Rezept suchen',
      example: 'z. B. Porridge',
    );
    handle.dispose();
  });

  testWidgets('the recipe search keeps „Rezept suchen" with text entered; '
      'its clear button is „Suche löschen"', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'curry');
    await tester.pump(const Duration(milliseconds: 350));

    final field = tester.getSemantics(find.byType(EditableText));
    expect(field.getSemanticsData().label, contains('Rezept suchen'));
    expect(field, isSemantics(isTextField: true, value: 'curry'));

    final clear = find.semantics.byPredicate(
      (n) => n.tooltip == 'Suche löschen' && !n.isMergedIntoParent,
    );
    expect(clear, findsOneWidget);
    tester.semantics.tap(clear);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('curry'), findsNothing);
    handle.dispose();
  });

  testWidgets('prefills the field from the notifier active query', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        userRecipeRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue(testUserId),
      ],
    );
    addTearDown(container.dispose);

    // Seed an active query before the widget mounts (a screen keeps the
    // search alive).
    container.listen(
      recipeSearchProvider(RecipeSearchHost.myRecipes),
      (_, _) {},
    );
    await container.read(userRecipesProvider.notifier).fetch();
    container
        .read(recipeSearchProvider(RecipeSearchHost.myRecipes).notifier)
        .setQuery('reis');
    // Advance fake time past the 300 ms debounce so the timer fires.
    await tester.pump(const Duration(milliseconds: 350));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: RecipesSearchField(host: RecipeSearchHost.myRecipes),
          ),
        ),
      ),
    );
    // Single pump is enough — initState already set the controller text.
    await tester.pump();

    expect(find.text('reis'), findsOneWidget);
  });
}
