import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/alternative_choice.dart';
import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/models/replacement_ingredient.dart';
import 'package:belly_buddy/services/alternatives/alternative_ranking.dart';

ReplacementIngredient _r(String id, [String? name]) =>
    ReplacementIngredient(id: id, name: name ?? id);

MealIngredients _meal(DateTime at, List<String> ingredients) =>
    (trackedAt: at, ingredients: ingredients);

AlternativeChoice _choice(
  String ingredientId,
  String replacementId,
  String replacementName,
  AlternativeChoiceKind kind,
) => AlternativeChoice(
  id: '$ingredientId-$replacementId',
  ingredientId: ingredientId,
  ingredientName: ingredientId,
  replacementId: replacementId,
  replacementName: replacementName,
  kind: kind,
  createdAt: DateTime.utc(2026, 11, 1),
);

List<String> _ids(List<RankedReplacement> ranked) => [
  for (final r in ranked) r.id,
];

void main() {
  // The suggestion was made on 10.11. (local); meals are wall clock.
  final since = DateTime(2026, 11, 10, 12).toUtc();
  final later = DateTime(2026, 11, 12, 13);

  group('baseName', () {
    test('lower case, trimmed, cut at the first " ("', () {
      expect(baseName('  Tofu (fest, natur) '), 'tofu');
      expect(baseName('Hafermilch'), 'hafermilch');
      expect(baseName('Reis (Basmati) (gekocht)'), 'reis');
    });
  });

  group('rankKeyedReplacements', () {
    test(
      'liked first, eaten-after next, neutral, sibling of disliked, disliked last',
      () {
        final ranked = rankKeyedReplacements(
          [
            _r('skip', 'Mandelmilch'),
            _r('sib', 'Reis (Basmati)'),
            _r('neutral', 'Quinoa'),
            _r('eaten', 'Hirse'),
            _r('try', 'Buchweizen'),
            _r('fits', 'Hafermilch'),
          ],
          verdicts: {
            'skip': AlternativeChoiceKind.skip,
            'try': AlternativeChoiceKind.tryIt,
            'fits': AlternativeChoiceKind.fits,
          },
          skippedBaseNames: {'reis'},
          meals: KeyedMeals([
            _meal(later, ['Hirse']),
          ]),
          since: since,
        );
        expect(_ids(ranked), [
          'fits',
          'eaten',
          'try',
          'neutral',
          'sib',
          'skip',
        ]);
        expect([for (final r in ranked) r.tier], [0, 1, 1, 2, 3, 4]);
      },
    );

    test('within a tier: more meals eaten after first, then the original '
        'order', () {
      final ranked = rankKeyedReplacements(
        [_r('a'), _r('b'), _r('c'), _r('d')],
        verdicts: const {},
        meals: KeyedMeals([
          _meal(later, ['c']),
          _meal(later.add(const Duration(days: 1)), ['c', 'b']),
          _meal(later, ['b']),
          _meal(later, ['d']),
        ]),
        since: since,
      );
      expect(_ids(ranked), ['b', 'c', 'd', 'a']);
      expect([for (final r in ranked) r.eatenAfter], [2, 2, 1, 0]);
    });

    test('a meal before the suggestion does not count', () {
      final ranked = rankKeyedReplacements(
        [_r('a'), _r('b')],
        verdicts: const {},
        meals: KeyedMeals([
          _meal(DateTime(2026, 11, 9, 20), ['b']),
          // The suggestion's own day: usually the meal that caused it.
          _meal(DateTime(2026, 11, 10, 23, 30), ['b']),
        ]),
        since: since,
      );
      expect(_ids(ranked), ['a', 'b']);
      expect(ranked.every((r) => r.eatenAfter == 0), isTrue);
    });

    test('created_at is an instant: its local date decides, tracked_at is '
        'taken as it is', () {
      final at = DateTime.utc(2026, 11, 10, 23, 30).toLocal();
      final ranked = rankKeyedReplacements(
        [_r('a'), _r('b')],
        verdicts: const {},
        meals: KeyedMeals([
          _meal(DateTime(at.year, at.month, at.day, 23, 59), ['a']),
          _meal(DateTime(at.year, at.month, at.day + 1, 0, 1), ['b']),
        ]),
        since: DateTime.utc(2026, 11, 10, 23, 30),
      );
      expect(_ids(ranked), ['b', 'a']);
      expect([for (final r in ranked) r.eatenAfter], [1, 0]);
    });

    test('without a suggestion time no meal counts', () {
      final ranked = rankKeyedReplacements(
        [_r('a'), _r('b')],
        verdicts: const {},
        meals: KeyedMeals([
          _meal(later, ['b']),
        ]),
        since: null,
      );
      expect(_ids(ranked), ['a', 'b']);
    });

    test('a meal counts once, however many of its ingredients match', () {
      final ranked = rankKeyedReplacements(
        [_r('t', 'Tofu')],
        verdicts: const {},
        meals: KeyedMeals([
          _meal(later, ['Tofu', 'Tofu (geräuchert)']),
        ]),
        since: since,
      );
      expect(ranked.single.eatenAfter, 1);
    });

    test('eaten-after matches by base name: „Tofu (fest, natur)" in a meal '
        'counts for „Tofu"', () {
      final ranked = rankKeyedReplacements(
        [_r('a', 'Quinoa'), _r('t', 'Tofu')],
        verdicts: const {},
        meals: KeyedMeals([
          _meal(later, ['Tofu (fest, natur)']),
        ]),
        since: since,
      );
      expect(_ids(ranked), ['t', 'a']);
      expect(ranked.first.eatenAfter, 1);
    });

    test('a sibling of a disliked item is demoted but visible', () {
      final ranked = rankKeyedReplacements(
        [_r('t1', 'Tofu (fest)'), _r('t2', 'Tofu (seiden)'), _r('q', 'Quinoa')],
        verdicts: {'t1': AlternativeChoiceKind.skip},
        meals: KeyedMeals(const []),
        since: since,
      );
      expect(_ids(ranked), ['q', 't2', 't1']);
      final group = IngredientSuggestionGroup(
        ingredientId: 'ing',
        ingredientName: 'Milch',
        mealCount: 0,
        isNew: false,
        suggestionIds: const [],
        replacements: ranked,
      );
      expect(_ids(group.visibleReplacements), ['q', 't2']);
    });

    test('all disliked: visible list empty', () {
      final ranked = rankKeyedReplacements(
        [_r('a'), _r('b')],
        verdicts: {
          'a': AlternativeChoiceKind.skip,
          'b': AlternativeChoiceKind.skip,
        },
        meals: KeyedMeals(const []),
        since: since,
      );
      final group = IngredientSuggestionGroup(
        ingredientId: 'ing',
        ingredientName: 'Milch',
        mealCount: 0,
        isNew: false,
        suggestionIds: const [],
        replacements: ranked,
      );
      expect(group.visibleReplacements, isEmpty);
      expect(_ids(ranked), ['a', 'b']);
    });

    test('no feedback and no meals: original order unchanged', () {
      final ranked = rankKeyedReplacements(
        [_r('c'), _r('a'), _r('b')],
        verdicts: const {},
        meals: KeyedMeals(const []),
        since: since,
      );
      expect(_ids(ranked), ['c', 'a', 'b']);
      expect(ranked.every((r) => r.tier == 2 && r.verdict == null), isTrue);
    });
  });

  group('AlternativeVerdicts', () {
    test('a verdict holds for its pairing; a skip demotes siblings on every '
        'pairing', () {
      final verdicts = AlternativeVerdicts([
        _choice('milch', 'hafer', 'Hafermilch', AlternativeChoiceKind.fits),
        _choice('milch', 'tofu1', 'Tofu (fest)', AlternativeChoiceKind.skip),
        _choice('ei', 'hafer', 'Hafermilch', AlternativeChoiceKind.skip),
      ]);
      expect(verdicts.forIngredient('milch'), {
        'hafer': AlternativeChoiceKind.fits,
        'tofu1': AlternativeChoiceKind.skip,
      });
      expect(verdicts.forIngredient('ei'), {
        'hafer': AlternativeChoiceKind.skip,
      });
      expect(verdicts.skippedBaseNames, {'tofu', 'hafermilch'});
    });
  });

  group('rerankGroups', () {
    test('ranks again with new choices, from the original order', () {
      final first = rankKeyedReplacements(
        [_r('a'), _r('b'), _r('c')],
        verdicts: const {},
        meals: KeyedMeals([
          _meal(later, ['c']),
        ]),
        since: since,
      );
      final group = IngredientSuggestionGroup(
        ingredientId: 'ing',
        ingredientName: 'Milch',
        mealCount: 0,
        isNew: false,
        suggestionIds: const [],
        replacements: first,
      );
      expect(_ids(group.replacements), ['c', 'a', 'b']);

      final skipped = rerankGroups(
        [group],
        [_choice('ing', 'a', 'a', AlternativeChoiceKind.skip)],
      ).single;
      expect(_ids(skipped.replacements), ['c', 'b', 'a']);
      expect(skipped.replacements.first.eatenAfter, 1);

      final reset = rerankGroups([skipped], const []).single;
      expect(_ids(reset.replacements), ['c', 'a', 'b']);
    });
  });
}
