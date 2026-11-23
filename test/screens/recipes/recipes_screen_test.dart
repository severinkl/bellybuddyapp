import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/recipe_search_provider.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/screens/recipes/my_recipes_tab.dart';
import 'package:belly_buddy/screens/recipes/recipes_screen.dart';
import 'package:belly_buddy/screens/trackers/meal/widgets/recipe_selector_sheet.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';
import '../../helpers/riverpod_helpers.dart';

/// The search under test (Meine Rezepte's).
final _search = recipeSearchProvider(RecipeSearchHost.myRecipes);

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
    expect(container.read(_search.notifier).activeQuery, 'zzz');
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

    expect(container.read(_search.exists), isFalse);
    expect(container.read(userRecipesProvider).value, hasLength(1));
  });

  testWidgets('Meine Rezepte and the recipe picker above it each keep '
      'their own search', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final pasta = testUserRecipe(
      id: 'p',
      title: 'Pasta Pesto',
      ingredients: const ['Nudeln'],
    );
    final rice = testUserRecipe(
      id: 'r',
      title: 'Reis Bowl',
      ingredients: const ['Basmati'],
    );
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => [pasta, rice]);
    when(() => repo.searchForUser(any(), any())).thenAnswer((invocation) async {
      final query = (invocation.positionalArguments[1] as String).toLowerCase();
      return [
        pasta,
        rice,
      ].where((r) => r.title.toLowerCase().contains(query)).toList();
    });
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRecipeRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          home: const RecipesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> search(String query) async {
      await tester.enterText(find.byType(TextField), query);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    // Meine Rezepte searches „pasta".
    await search('pasta');
    expect(find.text('Pasta Pesto'), findsOneWidget);
    expect(find.text('Reis Bowl'), findsNothing);

    // Meanwhile (Meine Rezepte still open below) the meal tracker's
    // „Rezept auswählen" sheet opens: its own, empty search, all recipes.
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showRecipeSelectorSheet(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.text('Pasta Pesto'), findsOneWidget);
    expect(find.text('Reis Bowl'), findsOneWidget);

    // The sheet searches „reis", then closes.
    await search('reis');
    expect(find.text('Reis Bowl'), findsOneWidget);
    expect(find.text('Pasta Pesto'), findsNothing);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    // Back on Meine Rezepte: still „pasta", field and grid.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'pasta',
    );
    expect(find.text('Pasta Pesto'), findsOneWidget);
    expect(find.text('Reis Bowl'), findsNothing);
  });

  testWidgets('the + opens the add-recipe chooser', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Rezept hinzufügen'), findsOneWidget);
  });
}
