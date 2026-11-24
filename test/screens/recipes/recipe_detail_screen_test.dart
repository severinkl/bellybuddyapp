import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/meal_prefill.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/router/route_names.dart';
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

    // The title shows once, as the page's heading.
    expect(find.text('Linseneintopf'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Rezept')),
      findsOneWidget,
    );
    expect(find.text('Linsen'), findsOneWidget);
    expect(find.text('Jetzt als Essen eintragen'), findsOneWidget);
  });

  testWidgets('"Jetzt als Essen eintragen" hands the tracker a MealPrefill', (
    tester,
  ) async {
    final recipe = testUserRecipe(
      id: 'rec-1',
      title: 'Linseneintopf',
      ingredients: const ['Linsen', 'Tomaten'],
    );
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => [recipe]);
    Object? extra;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const RecipeDetailScreen(recipeId: 'rec-1'),
        ),
        GoRoute(
          path: RoutePaths.mealTracker,
          builder: (_, state) {
            extra = state.extra;
            return const Scaffold(body: Text('tracker-sentinel'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRecipeRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jetzt als Essen eintragen'));
    await tester.pumpAndSettle();

    expect(find.text('tracker-sentinel'), findsOneWidget);
    expect(extra, isA<MealPrefill>());
    final prefill = extra! as MealPrefill;
    expect(prefill.title, 'Linseneintopf');
    expect(prefill.ingredients, ['Linsen', 'Tomaten']);
    expect(prefill.imageUrl, isNull);
  });

  testWidgets('VoiceOver reads ←, ✎ and 🗑 by name', (tester) async {
    final semantics = tester.ensureSemantics();
    final recipe = testUserRecipe(id: 'rec-1', title: 'Linseneintopf');
    await pumpDetail(tester, recipes: [recipe], id: 'rec-1');

    // VoiceOver reads an icon button's tooltip as its label.
    String spoken(IconData icon) =>
        tester.getSemantics(find.byIcon(icon)).tooltip;
    expect(spoken(Icons.arrow_back), 'Zurück');
    expect(spoken(Icons.edit_outlined), 'Bearbeiten');
    expect(spoken(Icons.delete_outline), 'Rezept löschen');
    semantics.dispose();
  });

  testWidgets('a recipe without a photo shows a placeholder', (tester) async {
    final recipe = testUserRecipe(id: 'rec-1', title: 'Linseneintopf');
    await pumpDetail(tester, recipes: [recipe], id: 'rec-1');

    expect(find.byKey(RecipeDetailScreen.imagePlaceholderKey), findsOneWidget);
  });

  testWidgets('shows not-found when recipe id is missing', (tester) async {
    await pumpDetail(tester, recipes: [], id: 'missing');

    expect(find.text('Rezept nicht gefunden'), findsOneWidget);
  });
}
