import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/adapted_recipe.dart';

/// The 200 answer of the API contract's example.
Map<String, dynamic> _contractExample() => {
  'recipe_id': 'recipe-1',
  'title': 'Zucchini-Risotto mit Knoblauchöl',
  'ingredients': [
    {
      'amount': '2 EL',
      'name': 'Knoblauchöl',
      'replaces': 'Knoblauch',
      'status': 'ok',
      'ingredient_id': 'ing-1',
    },
    {
      'amount': '200 g',
      'name': 'Risottoreis',
      'replaces': null,
      'status': 'ok',
      'ingredient_id': 'ing-2',
    },
    {
      'amount': '1 Prise',
      'name': 'Sumach',
      'replaces': null,
      'status': 'unbekannt',
      'ingredient_id': null,
    },
  ],
  'removed': ['Zwiebel'],
  'steps': [
    {'text': 'Erhitze das Knoblauchöl.', 'changed': true},
    {'text': 'Gib den Reis dazu.', 'changed': false},
  ],
  'note': 'Knoblauch und Zwiebel habe ich durch Knoblauchöl ersetzt.',
};

void main() {
  group('AdaptedRecipe.fromJson', () {
    test("fromJson of the contract's example", () {
      final adapted = AdaptedRecipe.fromJson(_contractExample());

      expect(adapted.recipeId, 'recipe-1');
      expect(adapted.title, 'Zucchini-Risotto mit Knoblauchöl');
      expect(adapted.ingredients, hasLength(3));
      expect(adapted.ingredients.map((i) => i.name), [
        'Knoblauchöl',
        'Risottoreis',
        'Sumach',
      ]);
      expect(adapted.ingredients.map((i) => i.amount), [
        '2 EL',
        '200 g',
        '1 Prise',
      ]);
      expect(adapted.ingredients.first.replaces, 'Knoblauch');
      expect(adapted.ingredients[1].replaces, isNull);
      expect(adapted.ingredients.map((i) => i.unknown), [false, false, true]);
      expect(adapted.removed, ['Zwiebel']);
      expect(adapted.steps.map((s) => s.text), [
        'Erhitze das Knoblauchöl.',
        'Gib den Reis dazu.',
      ]);
      expect(adapted.steps.map((s) => s.changed), [true, false]);
      expect(
        adapted.note,
        'Knoblauch und Zwiebel habe ich durch Knoblauchöl ersetzt.',
      );
      expect(adapted.unknownNames, ['Sumach']);
    });

    test('a blank amount or replaces is null', () {
      final ingredient = AdaptedIngredient.fromJson({
        'amount': '  ',
        'name': 'Reis',
        'replaces': '',
        'status': 'ok',
      });

      expect(ingredient.amount, isNull);
      expect(ingredient.replaces, isNull);
      expect(ingredient.unknown, isFalse);
    });

    test('blank names and steps are dropped, the rest trimmed', () {
      final json = _contractExample()
        ..['title'] = '  Risotto  '
        ..['ingredients'] = [
          {'amount': ' 200 g ', 'name': ' Risottoreis ', 'status': 'ok'},
          {'amount': '1 EL', 'name': '   ', 'status': 'ok'},
          {'name': 'Salz', 'status': 'ok'},
        ]
        ..['removed'] = [' Zwiebel ', '  ', 3]
        ..['steps'] = [
          {'text': '  Erhitze das Öl.  ', 'changed': true},
          {'text': '   ', 'changed': true},
          {'text': 'Gib den Reis dazu.'},
        ];

      final adapted = AdaptedRecipe.fromJson(json);

      expect(adapted.title, 'Risotto');
      expect(adapted.ingredients.map((i) => i.name), ['Risottoreis', 'Salz']);
      expect(adapted.ingredients.map((i) => i.amount), ['200 g', null]);
      expect(adapted.removed, ['Zwiebel']);
      expect(adapted.steps.map((s) => s.text), [
        'Erhitze das Öl.',
        'Gib den Reis dazu.',
      ]);
      expect(adapted.steps.map((s) => s.changed), [true, false]);
    });

    test('without removed, steps and note: empty', () {
      final json = _contractExample()
        ..remove('removed')
        ..remove('steps')
        ..remove('note');

      final adapted = AdaptedRecipe.fromJson(json);

      expect(adapted.removed, isEmpty);
      expect(adapted.steps, isEmpty);
      expect(adapted.note, '');
      expect(adapted.unknownNames, ['Sumach']);
    });

    for (final (label, change)
        in <(String, void Function(Map<String, dynamic>))>[
          ('no title', (json) => json.remove('title')),
          ('a blank title', (json) => json['title'] = ' '),
          ('no ingredients', (json) => json.remove('ingredients')),
          ('empty ingredients', (json) => json['ingredients'] = <dynamic>[]),
          ('ingredients not a list', (json) => json['ingredients'] = 'Reis'),
          ('an ingredient not a map', (json) => json['ingredients'] = ['Reis']),
          (
            'an ingredient without a name',
            (json) => json['ingredients'] = [
              {'amount': '1 EL', 'status': 'ok'},
            ],
          ),
          (
            'only blank ingredient names',
            (json) => json['ingredients'] = [
              {'amount': '1 EL', 'name': ' ', 'status': 'ok'},
            ],
          ),
          ('no recipe_id', (json) => json.remove('recipe_id')),
          ('steps not maps', (json) => json['steps'] = ['Kochen.']),
        ]) {
      test('throws a FormatException with $label', () {
        final json = _contractExample();
        change(json);

        expect(() => AdaptedRecipe.fromJson(json), throwsFormatException);
      });
    }
  });

  test('retryable: only when trying again may help', () {
    expect(
      {for (final f in AdaptFailure.values) f: f.retryable},
      {
        AdaptFailure.nothingToAdapt: false,
        AdaptFailure.cannotJudge: false,
        AdaptFailure.later: true,
        AdaptFailure.notFound: false,
        AdaptFailure.failed: true,
      },
    );
  });
}
