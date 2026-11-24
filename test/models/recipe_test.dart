import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/utils/food_words.dart';

Map<String, dynamic> _catalogRow({
  required String id,
  required String name,
  bool fructans = false,
}) => {
  'id': id,
  'name': name,
  'fodmap_fructans': fructans,
  'fodmap_gos': false,
  'fodmap_lactose': false,
  'fodmap_fructose': false,
  'fodmap_sorbitol': false,
  'fodmap_mannitol': false,
};

/// A `recipes` row as core's collection select returns it.
Map<String, dynamic> _contractRow() => {
  'id': 'recipe-risotto',
  'title': 'Zucchini-Risotto',
  'description': 'Cremig und mild.',
  'cook_time': '35 Min',
  'servings': 2,
  'image_url': null,
  'meal_types': ['abend', 'mittag', 'brunch'],
  'diet_tags': ['vegan', 'vegetarisch'],
  'source_name': 'Beispielküche',
  'source_url': 'https://example.org/risotto',
  'instructions': ['Reis anschwitzen.', 'Brühe nach und nach angießen.'],
  'ingredients': <dynamic>[],
  'created_at': '2026-11-24T08:00:00+00:00',
  'recipe_ingredients': [
    {
      'position': 1,
      'amount_text': '1 Zehe',
      'name': 'Knoblauch',
      'allergens': <dynamic>[],
      'low_at_amount': false,
      'ingredient': _catalogRow(
        id: 'ing-knoblauch',
        name: 'Knoblauch',
        fructans: true,
      ),
    },
    {
      'position': 0,
      'amount_text': '200 g',
      'name': 'Risottoreis',
      'allergens': <dynamic>[],
      'low_at_amount': false,
      'ingredient': _catalogRow(id: 'ing-reis', name: 'Reis'),
    },
    {
      'position': 2,
      'amount_text': ' ',
      'name': 'Obst nach Wahl',
      'allergens': <dynamic>[],
      'low_at_amount': false,
      'ingredient': null,
    },
  ],
};

void main() {
  group('Recipe.fromJson', () {
    test('reads a contract-shaped row', () {
      final recipe = Recipe.fromJson(_contractRow());

      expect(recipe.id, 'recipe-risotto');
      expect(recipe.title, 'Zucchini-Risotto');
      expect(recipe.description, 'Cremig und mild.');
      expect(recipe.cookTime, '35 Min');
      expect(recipe.servings, 2);
      expect(recipe.imageUrl, isNull);
      expect(recipe.dietTags, {'vegan', 'vegetarisch'});
      expect(recipe.sourceName, 'Beispielküche');
      expect(recipe.sourceUrl, 'https://example.org/risotto');
      expect(recipe.instructions, [
        'Reis anschwitzen.',
        'Brühe nach und nach angießen.',
      ]);
      expect(recipe.createdAt, DateTime.utc(2026, 11, 24, 8));
      expect(recipe.isLegacy, isFalse);

      expect(recipe.ingredients.map((l) => l.name), [
        'Risottoreis',
        'Knoblauch',
        'Obst nach Wahl',
      ]);
      expect(recipe.mealTypes, [MealType.lunch, MealType.dinner]);

      final reis = recipe.ingredients[0];
      expect(reis.amount, '200 g');
      expect(reis.catalogId, 'ing-reis');
      expect(reis.catalogName, 'Reis');
      expect(reis.mapped, isTrue);
      expect(reis.isFood(FoodName('risottoreis')), isTrue);
      expect(reis.isFood(FoodName('Reis')), isTrue);
      expect(reis.isFood(FoodName('Milchreis')), isFalse);

      final knoblauch = recipe.ingredients[1];
      expect(knoblauch.position, 1);
      expect(knoblauch.fodmaps!.fructans, isTrue);
      expect(knoblauch.lowAtAmount, isFalse);
      expect(knoblauch.isFood(FoodName('knoblauch')), isTrue);

      final obst = recipe.ingredients[2];
      expect(obst.mapped, isFalse);
      expect(obst.fodmaps, isNull);
      expect(obst.amount, isNull);
      expect(obst.catalogName, isNull);
      expect(obst.isFood(FoodName('obst nach wahl')), isTrue);
      expect(obst.isFood(FoodName('Obst')), isTrue);

      expect(recipe.detailMeta, '35 Min · 2 Portionen');
      expect(recipe.listMeta, '35 Min · Mittag');
    });

    test('servings 1 reads 1 Portion', () {
      final recipe = Recipe.fromJson({..._contractRow(), 'servings': 1});

      expect(recipe.servingsLabel, '1 Portion');
      expect(recipe.detailMeta, '35 Min · 1 Portion');
    });

    test('an older recipe', () {
      final recipe = Recipe.fromJson({
        'id': 'recipe-old',
        'title': 'Reispfanne',
        'description': null,
        'cook_time': null,
        'servings': null,
        'image_url': 'https://example.org/reis.jpg',
        'meal_types': <dynamic>[],
        'diet_tags': <dynamic>[],
        'source_name': null,
        'source_url': null,
        'instructions': ['Reis kochen.'],
        'ingredients': ['200 g Reis'],
        'created_at': '2025-03-01T12:00:00+00:00',
        'recipe_ingredients': <dynamic>[],
      });

      expect(recipe.isLegacy, isTrue);
      expect(recipe.ingredients, isEmpty);
      expect(recipe.legacyIngredients, ['200 g Reis']);
      expect(recipe.dietTags, isEmpty);
      expect(recipe.mealTypes, isEmpty);
      expect(recipe.servingsLabel, isNull);
      expect(recipe.detailMeta, '');
      expect(recipe.listMeta, '');
    });

    test('sourceLabel: the name, else the site, else null', () {
      Recipe source({String? name, String? url}) => Recipe.fromJson({
        ..._contractRow(),
        'source_name': name,
        'source_url': url,
      });

      expect(
        source(name: 'Reizdarmblog', url: 'https://x.de/a').sourceLabel,
        'Reizdarmblog',
      );
      expect(
        source(name: '  ', url: 'https://www.reizdarmblog.de/a').sourceLabel,
        'www.reizdarmblog.de',
      );
      expect(source(name: 'Reizdarmblog').sourceLabel, 'Reizdarmblog');
      expect(source(url: 'keine url').sourceLabel, isNull);
      expect(source(url: 'ftp://files.example.de/a').sourceLabel, isNull);
      expect(source().sourceLabel, isNull);
    });

    test('sourceLink: a web link, trimmed; null otherwise', () {
      Recipe source(String? url) =>
          Recipe.fromJson({..._contractRow(), 'source_url': url});

      expect(
        source('  https://www.reizdarmblog.de/a ').sourceLink,
        'https://www.reizdarmblog.de/a',
      );
      expect(source('http://x.de/a').sourceLink, 'http://x.de/a');
      expect(source('ftp://files.example.de/a').sourceLink, isNull);
      expect(source('javascript:alert(1)').sourceLink, isNull);
      expect(source('www.reizdarmblog.de').sourceLink, isNull);
      expect(source('  ').sourceLink, isNull);
      expect(source(null).sourceLink, isNull);
    });

    test('a numeric or blank cook_time', () {
      expect(
        Recipe.fromJson({..._contractRow(), 'cook_time': 25}).cookTime,
        '25',
      );
      final blank = Recipe.fromJson({..._contractRow(), 'cook_time': '  '});
      expect(blank.cookTime, isNull);
      expect(blank.detailMeta, '2 Portionen');
      expect(blank.listMeta, 'Mittag');
    });
  });

  group('RecipeIngredient', () {
    test('fromJson reads allergens and low_at_amount', () {
      final line = RecipeIngredient.fromJson({
        'position': 3,
        'amount_text': '1 EL',
        'name': 'Weizenmehl',
        'allergens': ['gluten', 'weizen'],
        'low_at_amount': true,
        'ingredient': _catalogRow(id: 'ing-mehl', name: 'Weizenmehl'),
      });

      expect(line.position, 3);
      expect(line.allergens, {'gluten', 'weizen'});
      expect(line.lowAtAmount, isTrue);
      expect(line.fodmaps!.hasAny, isFalse);
    });

    test('isFood: the name or catalog name, case and spaces ignored; '
        'a blank food never', () {
      final line = RecipeIngredient(
        position: 0,
        name: ' Knoblauch ',
        catalogId: 'ing-1',
        catalogName: '  ',
      );

      expect(line.isFood(FoodName('KNOBLAUCH')), isTrue);
      expect(line.isFood(FoodName('')), isFalse);
      expect(line.isFood(FoodName('  ')), isFalse);
    });

    test('isFood: the catalog name in another spelling too, like core '
        '(the food rules: food_words_test)', () {
      final gewuerz = RecipeIngredient(
        position: 1,
        name: 'Gewürz',
        catalogId: 'ing-zwiebelpulver',
        catalogName: 'Zwiebelpulver',
      );

      expect(gewuerz.isFood(FoodName('Zwiebeln')), isTrue);
      expect(gewuerz.isFood(FoodName('Frühlingszwiebelgrün')), isFalse);
    });
  });

  group('MealType.fromKey', () {
    test('reads the contract keys and drops unknown ones', () {
      expect(MealType.fromKey('frühstück'), MealType.breakfast);
      expect(MealType.fromKey('mittag'), MealType.lunch);
      expect(MealType.fromKey('abend'), MealType.dinner);
      expect(MealType.fromKey('snack'), MealType.snack);
      expect(MealType.fromKey('brunch'), isNull);
    });
  });
}
