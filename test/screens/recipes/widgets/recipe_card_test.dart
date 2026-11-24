import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/my_recipe_item.dart';
import 'package:belly_buddy/models/user_recipe.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_card.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_collection_card.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: SizedBox(width: 200, height: 280, child: child)),
        ),
      ),
    );
  }

  testWidgets('renders title and ingredients line', (tester) async {
    final recipe = testUserRecipe(
      title: 'Curry mit Reis',
      ingredients: const ['Reis', 'Curry', 'Kokosmilch', 'Zwiebel'],
    );
    await pump(tester, RecipeCard(recipe: recipe, onTap: () {}));

    expect(find.text('Curry mit Reis'), findsOneWidget);
    expect(find.textContaining('Reis · Curry · Kokosmilch'), findsOneWidget);
    expect(find.textContaining('Zwiebel'), findsNothing);
  });

  testWidgets('renders pastel monogram when imageUrl is null', (tester) async {
    final recipe = testUserRecipe(title: 'Pasta', imageUrl: null);
    await pump(tester, RecipeCard(recipe: recipe, onTap: () {}));

    // Title's first letter, uppercased.
    expect(find.text('P'), findsOneWidget);
  });

  testWidgets('tap fires onTap', (tester) async {
    var tapped = false;
    final recipe = testUserRecipe();
    await pump(tester, RecipeCard(recipe: recipe, onTap: () => tapped = true));

    await tester.tap(find.byType(RecipeCard));
    expect(tapped, isTrue);
  });

  testWidgets('falls back to "?" monogram for empty title', (tester) async {
    final recipe = testUserRecipe(title: '', imageUrl: null);
    await pump(tester, RecipeCard(recipe: recipe, onTap: () {}));

    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('an adapted own recipe shows Angepasst', (tester) async {
    final recipe = testUserRecipe().copyWith(adaptedFromRecipeId: 'recipe-1');
    await pump(tester, RecipeCard(recipe: recipe, onTap: () {}));
    expect(find.text('Angepasst'), findsOneWidget);
  });

  testWidgets('a plain own recipe has no tag', (tester) async {
    await pump(tester, RecipeCard(recipe: testUserRecipe(), onTap: () {}));
    expect(find.text('Angepasst'), findsNothing);
  });

  group('MyRecipeCard', () {
    late List<UserRecipe> own;
    late List<String> saved;

    setUp(() {
      own = [];
      saved = [];
    });

    Widget card(MyRecipeItem item) =>
        MyRecipeCard(item: item, onOpenOwn: own.add, onOpenSaved: saved.add);

    testWidgets('an own recipe: its card, opened as own', (tester) async {
      final recipe = testUserRecipe(title: 'Curry mit Reis');
      await pump(tester, card(OwnRecipe(recipe)));

      expect(find.byType(RecipeCard), findsOneWidget);
      expect(find.text('Gemerkt'), findsNothing);
      await tester.tap(find.byType(MyRecipeCard));
      expect(own, [recipe]);
      expect(saved, isEmpty);
    });

    testWidgets('a saved recipe: with the heart, opened by id', (tester) async {
      final recipe = testRecipe(id: 'c1', title: 'Reispfanne');
      await pump(tester, card(SavedRecipe(recipe, DateTime(2026, 11, 24))));

      expect(find.byType(RecipeCollectionCard), findsOneWidget);
      expect(find.text('Gemerkt'), findsOneWidget);
      expect(find.text('Reispfanne'), findsOneWidget);
      await tester.tap(find.byType(MyRecipeCard));
      expect(saved, ['c1']);
      expect(own, isEmpty);
    });
  });
}
