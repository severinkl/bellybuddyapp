import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/recipes/widgets/recipe_card.dart';

import '../../../helpers/fakes.dart';

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
}
