import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
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

    group('the ingredient\'s image', () {
      List<IngredientSuggestionGroup> build(
        String? ownImage,
        List<(String, String?)> replacements,
      ) => SuggestionHelpers.buildGroups(
        suggestionData: [
          {
            'id': 's1',
            'detected_ingredient_id': 'ing1',
            'ingredients': {'name': 'Tofu', 'image_url': ownImage},
            'meal_id': null,
            'seen_at': null,
          },
        ],
        replacementsData: [
          for (final (i, (name, url)) in replacements.indexed)
            {
              'suggestion_id': 's1',
              'ingredients': {'id': 'r$i', 'name': name, 'image_url': url},
            },
        ],
        mealsData: [],
      );

      test('is its own when it has one', () {
        final groups = build('https://img/tofu.png', [
          ('Tofu (fest, natur)', 'https://img/tofu-fest.png'),
        ]);
        expect(groups.single.ingredientImageUrl, 'https://img/tofu.png');
      });

      test('without one, is that of the same food in a variety', () {
        final groups = build(null, [
          ('Halloumi', 'https://img/halloumi.png'),
          ('Tofu (fest, natur)', 'https://img/tofu-fest.png'),
        ]);
        expect(groups.single.ingredientImageUrl, 'https://img/tofu-fest.png');
      });

      test('is never that of another food', () {
        final groups = build(null, [
          ('Halloumi', 'https://img/halloumi.png'),
          ('Tofuwurst', 'https://img/tofuwurst.png'),
        ]);
        expect(groups.single.ingredientImageUrl, isNull);
      });
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

  group('a group whose ingredient row is hidden', () {
    // Row level security can hide the detected ingredient's row: the
    // embedded `ingredients` is then null, but the help text and the meal
    // still say which ingredient it is.
    const tofuHelp =
        'Tofu ist eine tolle Proteinquelle für deine vegetarische Bowl. '
        'Weicher oder Seidentofu kann aber Galakto-Oligosaccharide (GOS) '
        'enthalten. Halloumi ist von Natur aus sehr laktosearm.';

    Map<String, dynamic> hiddenRow({String? helptext, String? mealId}) => {
      'id': 's1',
      'detected_ingredient_id': 'ing-tofu',
      'ingredients': null,
      'meal_id': mealId,
      'seen_at': null,
      'helptext': helptext,
    };

    Map<String, dynamic> meal(List<String> ingredients) => {
      'id': 'm1',
      'title': 'Bowl mit gebratenem Tofu, Gemüse und Wachteleiern',
      'tracked_at': '2026-11-23T12:00:00',
      'image_url': null,
      'ingredients': ingredients,
    };

    test('is named after the meal ingredient its help text is about', () {
      final groups = SuggestionHelpers.buildGroups(
        suggestionData: [hiddenRow(helptext: tofuHelp, mealId: 'm1')],
        replacementsData: [],
        mealsData: [
          meal(['Reis', 'Wachteleier', 'Tofu', 'Brokkoli']),
        ],
      );

      expect(groups.single.ingredientName, 'Tofu');
      expect(groups.single.meals.single.ingredients, contains('Tofu'));
    });

    test('an ingredient name inside another word does not count', () {
      final groups = SuggestionHelpers.buildGroups(
        suggestionData: [
          hiddenRow(
            helptext: 'Eiweißreich, aber Knoblauch enthält Fruktane.',
            mealId: 'm1',
          ),
        ],
        replacementsData: [],
        mealsData: [
          meal(['Ei', 'Knoblauch']),
        ],
      );

      expect(groups.single.ingredientName, 'Knoblauch');
    });

    test('the fallback help text names it too', () {
      final groups = SuggestionHelpers.buildGroups(
        suggestionData: [
          hiddenRow(
            helptext:
                'Knoblauch enthält Fruktane, was bei empfindlichen Personen '
                'Beschwerden auslösen kann. Probiere sanfte Alternativen!',
          ),
        ],
        replacementsData: [],
        mealsData: [],
      );

      expect(groups.single.ingredientName, 'Knoblauch');
    });

    test('without any hint it is an „Unbekannte Zutat", never „Unbekannt"', () {
      final groups = SuggestionHelpers.buildGroups(
        suggestionData: [hiddenRow()],
        replacementsData: [],
        mealsData: [],
      );

      expect(groups.single.ingredientName, 'Unbekannte Zutat');
    });
  });
}
