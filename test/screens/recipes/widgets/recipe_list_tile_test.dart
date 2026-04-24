import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/recipes/widgets/recipe_list_tile.dart';

import '../../../helpers/fakes.dart';

void main() {
  testWidgets('renders title and truncated ingredients', (tester) async {
    final recipe = testUserRecipe(
      title: 'Curry mit Reis',
      ingredients: const ['Reis', 'Curry', 'Zwiebel', 'Knoblauch', 'Salz'],
    );
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipeListTile(recipe: recipe, onTap: () => tapped = true),
        ),
      ),
    );

    expect(find.text('Curry mit Reis'), findsOneWidget);
    // First 3 joined by " · "; 4th and 5th truncated away.
    expect(find.textContaining('Reis · Curry · Zwiebel'), findsOneWidget);
    expect(find.textContaining('Knoblauch'), findsNothing);

    await tester.tap(find.byType(RecipeListTile));
    expect(tapped, isTrue);
  });

  testWidgets('renders fallback icon when imageUrl is null', (tester) async {
    final recipe = testUserRecipe(imageUrl: null);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipeListTile(recipe: recipe, onTap: () {}),
        ),
      ),
    );

    expect(find.byIcon(Icons.restaurant_menu_outlined), findsOneWidget);
  });
}
