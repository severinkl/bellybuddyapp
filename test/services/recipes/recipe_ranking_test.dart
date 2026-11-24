import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/fodmap_flags.dart';
import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/services/recipes/recipe_fit.dart';
import 'package:belly_buddy/services/recipes/recipe_ranking.dart';

import '../../helpers/fixtures.dart';

final _rules = testIntoleranceRules();

final _honig = testLine('Honig', fodmaps: const FodmapFlags(fructose: true));

/// Ranks [recipes] for a Fruktose user who eats everything.
RankedRecipes _rank(
  List<Recipe> recipes, {
  RankingSignals signals = const RankingSignals(),
}) => rankRecipes(
  recipes,
  diet: null,
  user: UserIntolerances(_rules, ['Fruktose']),
  signals: signals,
);

List<String> _ids(List<RecipeFit> fits) => [for (final f in fits) f.recipe.id];

Insights _insights({
  required bool unlocked,
  DayColumn goodDays = const DayColumn(days: 0),
  DayColumn hardDays = const DayColumn(days: 0),
  List<Noticed> noticed = const [],
  Set<String> calmDayIngredients = const {},
}) => Insights(
  progress: unlocked
      ? const InsightProgress(activeDays: 7, gutFeelingEntries: 3)
      : const InsightProgress(activeDays: 2, gutFeelingEntries: 1),
  calendar: const [],
  goodDays: goodDays,
  hardDays: hardDays,
  noticed: noticed,
  pick: const NothingYetPick(),
  calmDayIngredients: calmDayIngredients,
);

Noticed _noticed(String name, {bool uncertain = false}) => Noticed(
  name: name,
  hard: uncertain ? 2 : 3,
  hardDays: 3,
  good: 0,
  goodDays: 3,
  uncertain: uncertain,
);

void main() {
  group('fitsDiet', () {
    final vegan = testRecipe(dietTags: {'vegan', 'vegetarisch'});
    final vegetarian = testRecipe(dietTags: {'vegetarisch'});
    final omnivore = testRecipe(dietTags: const {});

    test('vegan keeps vegan recipes only', () {
      expect(fitsDiet(vegan, 'vegan'), isTrue);
      expect(fitsDiet(vegetarian, 'vegan'), isFalse);
      expect(fitsDiet(omnivore, 'vegan'), isFalse);
    });

    test('vegetarisch keeps both kinds and drops the rest', () {
      expect(fitsDiet(vegan, 'vegetarisch'), isTrue);
      expect(fitsDiet(vegetarian, 'vegetarisch'), isTrue);
      expect(fitsDiet(omnivore, 'vegetarisch'), isFalse);
    });

    test('alles and no diet keep everything', () {
      for (final diet in ['alles', null]) {
        for (final recipe in [vegan, vegetarian, omnivore]) {
          expect(fitsDiet(recipe, diet), isTrue, reason: '$diet');
        }
      }
    });

    test('rankRecipes hides what does not fit the diet', () {
      final ranked = rankRecipes(
        [
          testRecipe(id: 'vegan', dietTags: {'vegan', 'vegetarisch'}),
          testRecipe(id: 'vegetarisch', dietTags: {'vegetarisch'}),
          testRecipe(id: 'alles', dietTags: const {}),
        ],
        diet: 'vegan',
        user: UserIntolerances(_rules, const []),
        signals: const RankingSignals(),
      );

      expect(_ids(ranked.fits), ['vegan']);
      expect(ranked.hiddenByDiet, 2);
      expect(ranked.diet, 'vegan');
    });
  });

  group('recipeScore', () {
    final reis = testLine('Reis');
    final karotte = testLine('Karotte');
    final zwiebel = testLine('Zwiebel');

    test('2 per good ingredient', () {
      final recipe = testRecipe(ingredients: [reis, karotte]);
      expect(
        recipeScore(recipe, const RankingSignals(good: {'reis', 'karotte'})),
        4,
      );
    });

    test('minus 3 per noticed ingredient', () {
      final recipe = testRecipe(ingredients: [reis, karotte, zwiebel]);
      expect(
        recipeScore(
          recipe,
          const RankingSignals(good: {'reis', 'karotte'}, noticed: {'zwiebel'}),
        ),
        1,
      );
    });

    test('matches the catalog name too', () {
      const paprika = RecipeIngredient(
        position: 0,
        name: 'Rote Paprika',
        catalogId: 'ing-paprika',
        catalogName: 'Paprika',
        fodmaps: FodmapFlags(),
      );
      final recipe = testRecipe(ingredients: [paprika]);
      expect(recipeScore(recipe, const RankingSignals(good: {'paprika'})), 2);
    });

    test('an ingredient counts once', () {
      final recipe = testRecipe(
        ingredients: [reis, testLine('Reis', position: 1)],
      );
      expect(recipeScore(recipe, const RankingSignals(good: {'reis'})), 2);
    });

    test('an older recipe scores 0', () {
      const older = Recipe(
        id: 'old',
        title: 'Altes Rezept',
        legacyIngredients: ['Reis'],
      );
      expect(recipeScore(older, const RankingSignals(good: {'reis'})), 0);
    });
  });

  group('order', () {
    test('a higher score first', () {
      final ranked = _rank([
        testRecipe(id: 'a', title: 'A', ingredients: [testLine('Nudeln')]),
        testRecipe(id: 'b', title: 'B', ingredients: [testLine('Reis')]),
      ], signals: const RankingSignals(good: {'reis'}));
      expect(_ids(ranked.fits), ['b', 'a']);
    });

    test('equal scores: fewer kritisch ingredients first', () {
      final ranked = _rank([
        testRecipe(id: 'a', title: 'A', ingredients: [_honig]),
        testRecipe(id: 'b', title: 'B', ingredients: [testLine('Reis')]),
      ]);
      expect(_ids(ranked.fits), ['b', 'a']);
    });

    test('then the newer first, without a date last', () {
      final ranked = _rank([
        testRecipe(id: 'none', title: 'A'),
        testRecipe(id: 'old', title: 'B', createdAt: DateTime(2026, 11, 1)),
        testRecipe(id: 'new', title: 'C', createdAt: DateTime(2026, 11, 20)),
      ]);
      expect(_ids(ranked.fits), ['new', 'old', 'none']);
    });

    test('then by title', () {
      final at = DateTime(2026, 11, 1);
      final ranked = _rank([
        testRecipe(id: 'b', title: 'Bohnen', createdAt: at),
        testRecipe(id: 'a', title: 'Apfel', createdAt: at),
      ]);
      expect(_ids(ranked.fits), ['a', 'b']);
    });

    test('checked and selfCheck as for the user', () {
      final histamin = rankRecipes(
        const [],
        diet: null,
        user: UserIntolerances(_rules, ['Histamin', 'Fruktose']),
        signals: const RankingSignals(),
      );
      expect(histamin.checked, isTrue);
      expect(histamin.selfCheck, ['Histamin']);
      expect(histamin.fits, isEmpty);

      final unknown = rankRecipes(
        [testRecipe()],
        diet: null,
        user: UserIntolerances(null, ['Histamin']),
        signals: const RankingSignals(),
      );
      expect(unknown.checked, isFalse);
      expect(unknown.selfCheck, isEmpty);
      expect(unknown.fits.single.checked, isFalse);
    });
  });

  group('RankingSignals.of', () {
    test('no insights: no signals', () {
      final signals = RankingSignals.of(null);
      expect(signals.good, isEmpty);
      expect(signals.noticed, isEmpty);
    });

    test('locked: the calm-day ingredients, nothing noticed', () {
      final signals = RankingSignals.of(
        _insights(
          unlocked: false,
          hardDays: const DayColumn(days: 3),
          noticed: [_noticed('Zwiebel')],
          calmDayIngredients: {'reis', 'karotte'},
        ),
      );
      expect(signals.good, {'reis', 'karotte'});
      expect(signals.noticed, isEmpty);
    });

    test('unlocked: the good days and the certain noticed, lower-cased', () {
      final signals = RankingSignals.of(
        _insights(
          unlocked: true,
          goodDays: const DayColumn(
            days: 4,
            often: [
              IngredientCount('Reis', 3, of: 4),
              IngredientCount('Haferflocken', 2, of: 4),
            ],
          ),
          hardDays: const DayColumn(days: 3),
          noticed: [_noticed('Zwiebel'), _noticed('Lauch', uncertain: true)],
          calmDayIngredients: {'brot'},
        ),
      );
      expect(signals.good, {'reis', 'haferflocken'});
      expect(signals.noticed, {'zwiebel'});
    });

    test('a column not shown gives nothing', () {
      final signals = RankingSignals.of(
        _insights(
          unlocked: true,
          goodDays: const DayColumn(
            days: 2,
            often: [IngredientCount('Reis', 2, of: 2)],
          ),
          hardDays: const DayColumn(days: 2),
          noticed: [_noticed('Zwiebel')],
        ),
      );
      expect(signals.good, isEmpty);
      expect(signals.noticed, isEmpty);
    });

    test('compare by value, so equal insights do not re-rank', () {
      const a = RankingSignals(good: {'reis'}, noticed: {'zwiebel'});
      // Equal sets, not the same ones.
      final names = ['reis', 'zwiebel'];
      final b = RankingSignals(good: {names[0]}, noticed: {names[1]});

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const RankingSignals(good: {'reis'})));
      expect(
        a,
        isNot(const RankingSignals(good: {'zwiebel'}, noticed: {'reis'})),
      );
      expect(RankingSignals.of(null), const RankingSignals());
    });
  });

  group('pickForYou', () {
    RecipeFit fit(String id, {bool kritisch = false, bool withRules = true}) =>
        fitOf(
          testRecipe(
            id: id,
            ingredients: [kritisch ? _honig : testLine('Reis')],
          ),
          rules: withRules ? _rules : null,
          intolerances: ['Fruktose'],
        );

    test('the passing ones first, then the best of the rest', () {
      final ranked = [
        fit('k1', kritisch: true),
        fit('p1'),
        fit('k2', kritisch: true),
        fit('p2'),
        fit('k3', kritisch: true),
      ];
      expect(_ids(pickForYou(ranked)), ['p1', 'p2', 'k1']);
    });

    test('enough passing ones: only those', () {
      final ranked = [
        fit('k1', kritisch: true),
        for (var i = 1; i <= 4; i++) fit('p$i'),
      ];
      expect(_ids(pickForYou(ranked)), ['p1', 'p2', 'p3']);
    });

    test('unchecked: the first 3', () {
      final ranked = [
        fit('k1', kritisch: true, withRules: false),
        fit('p1', withRules: false),
        fit('k2', kritisch: true, withRules: false),
        fit('p2', withRules: false),
      ];
      expect(_ids(pickForYou(ranked)), ['k1', 'p1', 'k2']);
    });

    test('fewer recipes than the count: all of them', () {
      expect(_ids(pickForYou([fit('k1', kritisch: true)])), ['k1']);
      expect(pickForYou(const []), isEmpty);
    });
  });

  group('filterRecipes', () {
    final breakfast = testRecipe(
      id: 'porridge',
      title: 'Porridge',
      mealTypes: const [MealType.breakfast],
      ingredients: [testLine('Haferflocken')],
    );
    final pan = testRecipe(
      id: 'pfanne',
      title: 'Gemüsepfanne',
      mealTypes: const [MealType.lunch, MealType.dinner],
      ingredients: [testLine('Zucchini'), testLine('Knoblauch')],
    );
    final sweet = testRecipe(
      id: 'joghurt',
      title: 'Joghurt mit Honig',
      mealTypes: const [MealType.snack],
      ingredients: [_honig],
    );
    const older = Recipe(
      id: 'old',
      title: 'Altes Rezept',
      mealTypes: [MealType.dinner],
      legacyIngredients: ['200 g Reis'],
    );
    final ranked = [
      for (final r in [breakfast, pan, sweet, older])
        fitOf(r, rules: _rules, intolerances: ['Fruktose']),
    ];

    test('nothing set: all', () {
      expect(_ids(filterRecipes(ranked)), [
        'porridge',
        'pfanne',
        'joghurt',
        'old',
      ]);
    });

    test('by meal type', () {
      expect(_ids(filterRecipes(ranked, mealType: MealType.dinner)), [
        'pfanne',
        'old',
      ]);
      expect(_ids(filterRecipes(ranked, mealType: MealType.breakfast)), [
        'porridge',
      ]);
    });

    test('fitsOnly keeps the recipes that pass', () {
      // Joghurt has a kritisch line; the older recipe can't be judged.
      expect(_ids(filterRecipes(ranked, fitsOnly: true)), [
        'porridge',
        'pfanne',
      ]);
    });

    test('query: title, line names and older lines', () {
      expect(_ids(filterRecipes(ranked, query: 'knob')), ['pfanne']);
      expect(_ids(filterRecipes(ranked, query: '  KNOB ')), ['pfanne']);
      expect(_ids(filterRecipes(ranked, query: 'reis')), ['old']);
      expect(_ids(filterRecipes(ranked, query: 'porr')), ['porridge']);
      expect(_ids(filterRecipes(ranked, query: '   ')), hasLength(4));
      expect(filterRecipes(ranked, query: 'tofu'), isEmpty);
    });

    test('all together', () {
      expect(
        _ids(
          filterRecipes(
            ranked,
            query: 'e',
            mealType: MealType.dinner,
            fitsOnly: true,
          ),
        ),
        ['pfanne'],
      );
    });
  });
}
