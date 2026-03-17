import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/utils/recipe_tag_mapping.dart';

void main() {
  group('getAutoRecipeFilters', () {
    test('no diet, no intolerances returns empty set', () {
      expect(getAutoRecipeFilters(), <String>{});
    });

    test('vegetarisch diet returns Vegetarisch', () {
      expect(getAutoRecipeFilters(diet: 'vegetarisch'), {'Vegetarisch'});
    });

    test('vegan diet returns Vegan', () {
      expect(getAutoRecipeFilters(diet: 'vegan'), {'Vegan'});
    });

    test('unknown diet returns empty set', () {
      expect(getAutoRecipeFilters(diet: 'keto'), <String>{});
    });

    test('single intolerance Gluten returns Glutenfrei', () {
      expect(getAutoRecipeFilters(intolerances: ['Gluten']), {'Glutenfrei'});
    });

    test('multiple intolerances return multiple tags', () {
      expect(getAutoRecipeFilters(intolerances: ['Gluten', 'Laktose']), {
        'Glutenfrei',
        'Laktosefrei',
      });
    });

    test('combined diet and intolerances', () {
      expect(getAutoRecipeFilters(diet: 'vegan', intolerances: ['Gluten']), {
        'Vegan',
        'Glutenfrei',
      });
    });
  });
}
