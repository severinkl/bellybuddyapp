import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/utils/suggestion_helpers.dart';

void main() {
  group('SuggestionHelpers.buildGroups', () {
    test('empty input returns empty list', () {
      final groups = SuggestionHelpers.buildGroups(
        suggestionData: [],
        replacementsData: [],
        mealsData: [],
      );
      expect(groups, isEmpty);
    });

    test('groups rows by detected_ingredient_id', () {
      final groups = SuggestionHelpers.buildGroups(
        suggestionData: [
          {
            'id': 's1',
            'detected_ingredient_id': 'ing1',
            'ingredients': {'name': 'Milch', 'image_url': null},
            'meal_id': 'm1',
            'seen_at': '2026-01-01',
            'helptext': 'help',
          },
          {
            'id': 's2',
            'detected_ingredient_id': 'ing1',
            'ingredients': {'name': 'Milch', 'image_url': null},
            'meal_id': 'm2',
            'seen_at': '2026-01-01',
            'helptext': 'help',
          },
        ],
        replacementsData: [],
        mealsData: [],
      );
      expect(groups.length, 1);
      expect(groups.first.suggestionIds, ['s1', 's2']);
      expect(groups.first.mealCount, 2);
    });

    test('counts meals per ingredient', () {
      final groups = SuggestionHelpers.buildGroups(
        suggestionData: [
          {
            'id': 's1',
            'detected_ingredient_id': 'ing1',
            'ingredients': {'name': 'Milch'},
            'meal_id': 'm1',
            'seen_at': null,
          },
          {
            'id': 's2',
            'detected_ingredient_id': 'ing1',
            'ingredients': {'name': 'Milch'},
            'meal_id': 'm2',
            'seen_at': null,
          },
        ],
        replacementsData: [],
        mealsData: [],
      );
      expect(groups.first.mealCount, 2);
    });

    test('marks group as isNew when any row has null seen_at', () {
      final groups = SuggestionHelpers.buildGroups(
        suggestionData: [
          {
            'id': 's1',
            'detected_ingredient_id': 'ing1',
            'ingredients': {'name': 'Milch'},
            'meal_id': 'm1',
            'seen_at': '2026-01-01',
          },
          {
            'id': 's2',
            'detected_ingredient_id': 'ing1',
            'ingredients': {'name': 'Milch'},
            'meal_id': 'm2',
            'seen_at': null,
          },
        ],
        replacementsData: [],
        mealsData: [],
      );
      expect(groups.first.isNew, true);
    });

    test('isNew is false when all rows have seen_at', () {
      final groups = SuggestionHelpers.buildGroups(
        suggestionData: [
          {
            'id': 's1',
            'detected_ingredient_id': 'ing1',
            'ingredients': {'name': 'Milch'},
            'meal_id': 'm1',
            'seen_at': '2026-01-01',
          },
        ],
        replacementsData: [],
        mealsData: [],
      );
      expect(groups.first.isNew, false);
    });

    test('deduplicates replacements by ingredient ID', () {
      final groups = SuggestionHelpers.buildGroups(
        suggestionData: [
          {
            'id': 's1',
            'detected_ingredient_id': 'ing1',
            'ingredients': {'name': 'Milch'},
            'meal_id': null,
            'seen_at': null,
          },
          {
            'id': 's2',
            'detected_ingredient_id': 'ing1',
            'ingredients': {'name': 'Milch'},
            'meal_id': null,
            'seen_at': null,
          },
        ],
        replacementsData: [
          {
            'suggestion_id': 's1',
            'ingredients': {
              'id': 'r1',
              'name': 'Hafermilch',
              'image_url': null,
            },
          },
          {
            'suggestion_id': 's2',
            'ingredients': {
              'id': 'r1',
              'name': 'Hafermilch',
              'image_url': null,
            },
          },
        ],
        mealsData: [],
      );
      expect(groups.first.replacements.length, 1);
      expect(groups.first.replacements.first.name, 'Hafermilch');
    });

    test('indexes meals by ID', () {
      final groups = SuggestionHelpers.buildGroups(
        suggestionData: [
          {
            'id': 's1',
            'detected_ingredient_id': 'ing1',
            'ingredients': {'name': 'Milch'},
            'meal_id': 'm1',
            'seen_at': null,
          },
        ],
        replacementsData: [],
        mealsData: [
          {
            'id': 'm1',
            'title': 'Frühstück',
            'tracked_at': '2026-01-01T08:00:00',
            'image_url': null,
          },
        ],
      );
      expect(groups.first.meals.length, 1);
      expect(groups.first.meals.first.title, 'Frühstück');
    });

    test('sorts groups alphabetically by ingredient name', () {
      final groups = SuggestionHelpers.buildGroups(
        suggestionData: [
          {
            'id': 's1',
            'detected_ingredient_id': 'ing1',
            'ingredients': {'name': 'Zucker'},
            'meal_id': null,
            'seen_at': null,
          },
          {
            'id': 's2',
            'detected_ingredient_id': 'ing2',
            'ingredients': {'name': 'Apfel'},
            'meal_id': null,
            'seen_at': null,
          },
        ],
        replacementsData: [],
        mealsData: [],
      );
      expect(groups[0].ingredientName, 'Apfel');
      expect(groups[1].ingredientName, 'Zucker');
    });

    test('skips rows with null detected_ingredient_id', () {
      final groups = SuggestionHelpers.buildGroups(
        suggestionData: [
          {
            'id': 's1',
            'detected_ingredient_id': null,
            'ingredients': {'name': 'Milch'},
            'meal_id': null,
            'seen_at': null,
          },
        ],
        replacementsData: [],
        mealsData: [],
      );
      expect(groups, isEmpty);
    });
  });
}
