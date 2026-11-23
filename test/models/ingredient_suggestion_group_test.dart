import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/ingredient_suggestion_group.dart';

IngredientSuggestionGroup _group(
  String name, {
  bool isNew = false,
  List<DateTime> meals = const [],
}) => IngredientSuggestionGroup(
  ingredientId: 'ing-$name',
  ingredientName: name,
  mealCount: meals.length,
  isNew: isNew,
  suggestionIds: ['sug-$name'],
  meals: [
    for (final (i, at) in meals.indexed)
      MealDetail(id: 'meal-$name-$i', title: 'Essen', trackedAt: at),
  ],
);

List<String> _names(Iterable<IngredientSuggestionGroup> groups) =>
    groups.map((g) => g.ingredientName).toList();

void main() {
  group('IngredientSuggestionGroup.latestMeal', () {
    test('is null without meals', () {
      expect(_group('Zwiebel').latestMeal, isNull);
    });

    test('is the latest meal, whatever the order', () {
      final group = _group(
        'Zwiebel',
        meals: [
          DateTime(2026, 11, 18),
          DateTime(2026, 11, 21),
          DateTime(2026, 11, 19),
        ],
      );
      expect(group.latestMeal, DateTime(2026, 11, 21));
    });
  });

  group('IngredientSuggestionGroup.compareNewFirst', () {
    final groups = [
      _group('bohnen', meals: [DateTime(2026, 11, 20)]),
      _group('Apfel'),
      _group('Zwiebel', isNew: true, meals: [DateTime(2026, 11, 18)]),
      _group('Knoblauch', isNew: true, meals: [DateTime(2026, 11, 21)]),
      _group('Erbsen', meals: [DateTime(2026, 11, 22)]),
    ];

    test('new first, then by name ignoring case', () {
      final sorted = [...groups]
        ..sort(IngredientSuggestionGroup.compareNewFirst);
      expect(_names(sorted), [
        'Knoblauch',
        'Zwiebel',
        'Apfel',
        'bohnen',
        'Erbsen',
      ]);
    });

    test('with latestMealFirst: new first, then newest meal first, groups '
        'without meals last', () {
      final sorted = [...groups]
        ..sort(
          (a, b) => IngredientSuggestionGroup.compareNewFirst(
            a,
            b,
            latestMealFirst: true,
          ),
        );
      expect(_names(sorted), [
        'Knoblauch',
        'Zwiebel',
        'Erbsen',
        'bohnen',
        'Apfel',
      ]);
    });

    test('with latestMealFirst: the same latest meal falls back to the '
        'name', () {
      final at = DateTime(2026, 11, 20);
      final sorted =
          [
            _group('Zwiebel', meals: [at]),
            _group('apfel', meals: [at]),
          ]..sort(
            (a, b) => IngredientSuggestionGroup.compareNewFirst(
              a,
              b,
              latestMealFirst: true,
            ),
          );
      expect(_names(sorted), ['apfel', 'Zwiebel']);
    });
  });
}
