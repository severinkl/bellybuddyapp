import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/adapted_recipe.dart';
import 'package:belly_buddy/models/meal_prefill.dart';
import 'package:belly_buddy/models/recipe.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';

void main() {
  group('MealPrefill.ofRecipe', () {
    test('takes the names, trimmed, without duplicates, and no image', () {
      final recipe = testRecipe(
        title: 'Reisgericht',
        ingredients: [
          testLine('Reis'),
          testLine(' reis '),
          testLine('Knoblauchöl'),
        ],
      );

      final prefill = MealPrefill.ofRecipe(recipe);

      expect(prefill.title, 'Reisgericht');
      expect(prefill.ingredients, ['Reis', 'Knoblauchöl']);
      expect(prefill.imageUrl, isNull);
    });

    test('of an older recipe takes its lines', () {
      const recipe = Recipe(
        id: 'old',
        title: 'Altes Rezept',
        legacyIngredients: ['Hafer', ' ', 'Banane'],
      );

      expect(MealPrefill.ofRecipe(recipe).ingredients, ['Hafer', 'Banane']);
    });
  });

  test('ofAdapted names: trimmed, without duplicates, and no image', () {
    const adapted = AdaptedRecipe(
      recipeId: 'recipe-1',
      title: 'Porridge mit Ahornsirup',
      ingredients: [
        AdaptedIngredient(amount: '50 g', name: ' Haferflocken '),
        AdaptedIngredient(
          amount: '1 EL',
          name: 'Ahornsirup',
          replaces: 'Honig',
        ),
        AdaptedIngredient(name: 'haferflocken'),
        AdaptedIngredient(name: '  '),
        AdaptedIngredient(name: 'Sumach', unknown: true),
      ],
      removed: ['Zwiebel'],
      steps: [AdaptedStep('Kochen.')],
    );

    final prefill = MealPrefill.ofAdapted(adapted);

    expect(prefill.title, 'Porridge mit Ahornsirup');
    expect(prefill.ingredients, ['Haferflocken', 'Ahornsirup', 'Sumach']);
    expect(prefill.imageUrl, isNull);
  });

  test('ofUserRecipe keeps title, ingredients and image', () {
    final recipe = testUserRecipe(
      title: 'Porridge',
      ingredients: const ['Hafer', 'Banane'],
      imageUrl: 'https://example.com/p.jpg',
    );

    final prefill = MealPrefill.ofUserRecipe(recipe);

    expect(prefill.title, 'Porridge');
    expect(prefill.ingredients, ['Hafer', 'Banane']);
    expect(prefill.imageUrl, 'https://example.com/p.jpg');
  });
}
