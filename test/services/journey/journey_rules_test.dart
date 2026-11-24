import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/fodmap_flags.dart';
import 'package:belly_buddy/models/insight_source.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/models/journey_rewards.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/services/insights/insights_engine.dart';
import 'package:belly_buddy/services/journey/journey_copy.dart';
import 'package:belly_buddy/services/journey/journey_rules.dart';
import 'package:belly_buddy/services/recipes/recipe_fit.dart';
import 'package:belly_buddy/services/recipes/recipe_ranking.dart';
import 'package:belly_buddy/utils/date_format_utils.dart';

import '../../helpers/fixtures.dart';

final _rules = testIntoleranceRules();

final _honig = testLine('Honig', fodmaps: const FodmapFlags(fructose: true));

/// Ranks [recipes] for a Fruktose user who eats everything; [good] ranks
/// recipes up, and [checked] false leaves the intolerance table unknown.
RankedRecipes _rank(
  List<Recipe> recipes, {
  Set<String> good = const {},
  bool checked = true,
}) => rankRecipes(
  recipes,
  diet: null,
  user: UserIntolerances(checked ? _rules : null, ['Fruktose']),
  signals: RankingSignals(good: good),
);

Recipe _recipe(String id, List<String> lines, {String? title}) => testRecipe(
  id: id,
  title: title ?? id,
  ingredients: [for (final name in lines) testLine(name)],
);

/// Passes „Passt zu mir": no kritisch line.
final _a = _recipe('a', ['Reis'], title: 'Apfel-Reis');
final _c = _recipe('c', ['Kartoffel'], title: 'Couscous-Salat');

/// Kritisch for Fruktose (Honig).
final _b = testRecipe(id: 'b', title: 'Bananenbrot', ingredients: [_honig]);

/// Picks of days 1 and 3 that are not in the test collections.
const _earlier = {
  1: RecipePick(id: 'p1', title: 'Früher 1'),
  3: RecipePick(id: 'p3', title: 'Früher 3'),
};

final _now = DateTime(2026, 11, 24, 14);
final _today = DateTime(2026, 11, 24);
final _yesterday = DateTime(2026, 11, 23);

List<JourneyDay> _journeyUntil(DateTime last, int days) => [
  for (var i = days - 1; i >= 0; i--)
    JourneyDay(DateTime(last.year, last.month, last.day - i), gutFeeling: true),
];

void main() {
  group('advanceRewards', () {
    test('earned follows the active days, capped at 7', () {
      expect(
        advanceRewards(
          const JourneyRewards(),
          insights: lockedInsights(activeDays: 2),
          weeklyTips: null,
        ).earnedDay,
        2,
      );
      expect(
        advanceRewards(
          const JourneyRewards(),
          insights: lockedInsights(activeDays: 9),
          weeklyTips: null,
        ).earnedDay,
        7,
      );
    });

    test('never decreases', () {
      expect(
        advanceRewards(
          const JourneyRewards(earnedDay: 4),
          insights: lockedInsights(activeDays: 2),
          weeklyTips: null,
        ).earnedDay,
        4,
      );
    });

    test('patterns freed once unlocked, kept after', () {
      final unlocked = lockedInsights(activeDays: 7, gutFeelings: 3);
      expect(unlocked.unlocked, isTrue);
      final freed = advanceRewards(
        const JourneyRewards(earnedDay: 6),
        insights: unlocked,
        weeklyTips: null,
      );
      expect(freed.patternsFreed, isTrue);
      expect(freed.earnedDay, 7);
      final lockedAgain = advanceRewards(
        freed,
        insights: lockedInsights(activeDays: 5, gutFeelings: 2),
        weeklyTips: null,
      );
      expect(lockedAgain.patternsFreed, isTrue);
      expect(lockedAgain.earnedDay, 7);
    });

    test('day 3 waits for the weekly tips', () {
      final day3 = lockedInsights(activeDays: 3);
      expect(
        advanceRewards(
          const JourneyRewards(),
          insights: day3,
          weeklyTips: null,
        ).tipOffer,
        isNull,
      );
      expect(
        advanceRewards(
          const JourneyRewards(),
          insights: day3,
          weeklyTips: false,
        ).tipOffer,
        TipOffer.offered,
      );
      expect(
        advanceRewards(
          const JourneyRewards(),
          insights: lockedInsights(activeDays: 2),
          weeklyTips: false,
        ).tipOffer,
        isNull,
        reason: 'not before day 3',
      );
    });

    test('weekly on at day 3 → skipped', () {
      expect(
        advanceRewards(
          const JourneyRewards(),
          insights: lockedInsights(activeDays: 3),
          weeklyTips: true,
        ).tipOffer,
        TipOffer.skipped,
      );
    });

    test('decided once', () {
      for (final answer in TipOffer.values) {
        expect(
          advanceRewards(
            JourneyRewards(earnedDay: 3, tipOffer: answer),
            insights: lockedInsights(activeDays: 4),
            weeklyTips: answer == TipOffer.skipped ? false : true,
          ).tipOffer,
          answer,
        );
      }
    });

    test('nothing new → equal', () {
      const stored = JourneyRewards(
        earnedDay: 4,
        picks: _earlier,
        tipOffer: TipOffer.declined,
        firstTip: FirstTipState.done,
      );
      expect(
        advanceRewards(
          stored,
          insights: lockedInsights(activeDays: 4),
          weeklyTips: true,
        ),
        stored,
      );
      expect(
        advanceRewards(
          const JourneyRewards(),
          insights: lockedInsights(activeDays: 0, gutFeelings: 0),
          weeklyTips: null,
        ),
        const JourneyRewards(),
      );
    });
  });

  group('picks', () {
    test('day 1 = the first Für-dich recipe', () {
      // Honig ranks B first, but it is kritisch: „Für dich" starts with A.
      final ranked = _rank([_a, _b], good: {'honig'});
      expect(ranked.fits.first.recipe.id, 'b');
      final r = fillPicks(
        const JourneyRewards(earnedDay: 1),
        ranked: ranked,
        weeklyTips: false,
        calmKeys: const {},
      );
      expect(r.picks, {1: const RecipePick(id: 'a', title: 'Apfel-Reis')});
    });

    test('nothing before the day is earned', () {
      expect(
        fillPicks(
          const JourneyRewards(),
          ranked: _rank([_a, _c]),
          weeklyTips: false,
          calmKeys: const {},
        ).picks,
        isEmpty,
      );
    });

    test("day 3 skips day 1's pick", () {
      final r = fillPicks(
        const JourneyRewards(earnedDay: 3, tipOffer: TipOffer.declined),
        ranked: _rank([_a, _b, _c]),
        weeklyTips: false,
        calmKeys: const {},
      );
      expect(r.picks, {
        1: const RecipePick(id: 'a', title: 'Apfel-Reis'),
        3: const RecipePick(id: 'c', title: 'Couscous-Salat'),
      });
    });

    test('day 3 not picked while undecided or accepted', () {
      for (final answer in [null, TipOffer.accepted]) {
        final r = fillPicks(
          JourneyRewards(earnedDay: 4, tipOffer: answer),
          ranked: _rank([_a, _c]),
          weeklyTips: false,
          calmKeys: const {},
        );
        expect(r.picks.keys, [1], reason: '$answer');
      }
    });

    test('day 3 picked for offered, declined and skipped', () {
      for (final answer in [
        TipOffer.offered,
        TipOffer.declined,
        TipOffer.skipped,
      ]) {
        final r = fillPicks(
          JourneyRewards(earnedDay: 3, tipOffer: answer),
          ranked: _rank([_a, _c]),
          weeklyTips: false,
          calmKeys: const {},
        );
        expect(r.picks.keys, [1, 3], reason: '$answer');
        expect(r.picks[3]!.id, 'c', reason: '$answer');
      }
    });

    test('day 5 = the best passing recipe with a calm-day ingredient', () {
      final x = _recipe('x', ['Kartoffel', 'Lauch'], title: 'Kartoffelsuppe');
      final y = _recipe('y', [
        'Karotte',
        'Reis',
        'Zwiebel',
      ], title: 'Reispfanne');
      final ranked = _rank([x, y]);
      expect(ranked.fits.first.recipe.id, 'x');
      final r = fillPicks(
        const JourneyRewards(
          earnedDay: 5,
          picks: _earlier,
          tipOffer: TipOffer.declined,
        ),
        ranked: ranked,
        weeklyTips: false,
        calmKeys: const {'reis', 'karotte'},
      );
      expect(
        r.picks[5],
        const RecipePick(
          id: 'y',
          title: 'Reispfanne',
          matched: ['Karotte', 'Reis'],
        ),
      );
      expect(
        rewardTitle(5, r, weeklyTips: false),
        'Ein Rezept mit deinen Zutaten',
      );
    });

    test('day 5 without a match: the next recipe, matched empty, '
        'title Noch ein Rezept für dich', () {
      final x = _recipe('x', ['Kartoffel'], title: 'Kartoffelsuppe');
      final w = _recipe('w', ['Lauch'], title: 'Wok');
      final r = fillPicks(
        const JourneyRewards(
          earnedDay: 5,
          picks: _earlier,
          tipOffer: TipOffer.declined,
        ),
        ranked: _rank([x, w]),
        weeklyTips: false,
        calmKeys: const {'reis', 'karotte'},
      );
      expect(r.picks[5], const RecipePick(id: 'x', title: 'Kartoffelsuppe'));
      expect(rewardTitle(5, r, weeklyTips: false), 'Noch ein Rezept für dich');
    });

    test("a kritisch recipe's calm-day ingredient doesn't count", () {
      final x = _recipe('x', ['Kartoffel'], title: 'Kartoffelsuppe');
      final kritisch = testRecipe(
        id: 'k',
        title: 'Honigreis',
        ingredients: [testLine('Reis'), _honig],
      );
      final r = fillPicks(
        const JourneyRewards(earnedDay: 5, picks: _earlier),
        ranked: _rank([kritisch, x], good: {'reis'}),
        weeklyTips: false,
        calmKeys: const {'reis'},
      );
      expect(r.picks[5], const RecipePick(id: 'x', title: 'Kartoffelsuppe'));
    });

    test('day 5 names at most 3 matched lines, each once, in recipe order', () {
      final y = _recipe('y', [
        'Zucchini',
        'Reis',
        ' reis',
        'Lauch',
        'Karotte',
        'Kartoffel',
      ], title: 'Gemüsereis');
      final r = fillPicks(
        const JourneyRewards(earnedDay: 5, picks: _earlier),
        ranked: _rank([y]),
        weeklyTips: false,
        calmKeys: const {'reis', 'karotte', 'kartoffel', 'zucchini'},
      );
      expect(r.picks[5]!.matched, ['Zucchini', 'Reis', 'Karotte']);
    });

    test('day 5 matches the calm-day ingredients as the insights key them', () {
      final insights = computeInsights(
        InsightSource(
          meals: [
            InsightMeal(
              trackedAt: DateTime(2026, 11, 23, 12),
              ingredients: const ['  KAROTTE ', 'Reis'],
            ),
          ],
          gutFeelings: const [],
          activityTimes: [DateTime(2026, 11, 23, 12)],
        ),
        _now,
      );
      final y = _recipe('y', ['Karotte'], title: 'Karottensalat');
      final r = fillPicks(
        const JourneyRewards(earnedDay: 5, picks: _earlier),
        ranked: _rank([_c, y]),
        weeklyTips: false,
        calmKeys: insights.calmDayIngredients,
      );
      expect(r.picks[5]!.matched, ['Karotte']);
    });

    test('day 5 matches a calm-day food in another spelling, like core: '
        'Eier is Ei, Zwiebel is Zwiebelpulver', () {
      final x = _recipe('x', ['Kartoffel'], title: 'Kartoffelsuppe');
      final y = _recipe('y', [
        'Reis',
        'Ei',
        'Zwiebelpulver',
      ], title: 'Reispfanne mit Ei');
      final ranked = _rank([x, y]);
      expect(ranked.fits.first.recipe.id, 'x');
      final r = fillPicks(
        const JourneyRewards(earnedDay: 5, picks: _earlier),
        ranked: ranked,
        weeklyTips: false,
        calmKeys: const {'eier', 'zwiebel'},
      );
      expect(
        r.picks[5],
        const RecipePick(
          id: 'y',
          title: 'Reispfanne mit Ei',
          matched: ['Ei', 'Zwiebelpulver'],
        ),
      );
    });

    test('day 5: a free-from food is another food, matched by its own name '
        'only', () {
      final plain = _recipe('a', ['Milch', 'Brot'], title: 'Arme Ritter');
      final free = _recipe('b', [
        'Laktosefreie Milch',
        'Glutenfreies Brot',
      ], title: 'Brotauflauf');
      expect(_rank([plain, free]).fits.first.recipe.id, 'a');

      final calmFree = fillPicks(
        const JourneyRewards(earnedDay: 5, picks: _earlier),
        ranked: _rank([plain, free]),
        weeklyTips: false,
        calmKeys: const {'laktosefreie milch', 'glutenfreies brot'},
      );
      expect(
        calmFree.picks[5],
        const RecipePick(
          id: 'b',
          title: 'Brotauflauf',
          matched: ['Laktosefreie Milch', 'Glutenfreies Brot'],
        ),
      );

      final calmPlain = fillPicks(
        const JourneyRewards(earnedDay: 5, picks: _earlier),
        ranked: _rank([free]),
        weeklyTips: false,
        calmKeys: const {'milch', 'brot'},
      );
      expect(
        calmPlain.picks[5],
        const RecipePick(id: 'b', title: 'Brotauflauf'),
      );
    });

    test('day 5: another food with a similar name is no match', () {
      final y = _recipe('y', [
        'Frühlingszwiebelgrün',
        'Schnittlauch',
        'Kokosmilch',
        'Eisbergsalat',
        'Milchreis',
      ], title: 'Milchreis mit Kokos');
      final r = fillPicks(
        const JourneyRewards(earnedDay: 5, picks: _earlier),
        ranked: _rank([y]),
        weeklyTips: false,
        calmKeys: const {'zwiebel', 'milch', 'eier', 'reis', 'lauch'},
      );
      expect(
        r.picks[5],
        const RecipePick(id: 'y', title: 'Milchreis mit Kokos'),
      );
    });

    test('unchecked ranking: no pick', () {
      const r = JourneyRewards(earnedDay: 5, tipOffer: TipOffer.declined);
      expect(
        fillPicks(
          r,
          ranked: _rank([_a, _c], checked: false),
          weeklyTips: false,
          calmKeys: {},
        ),
        r,
      );
    });

    test('empty collection: no pick', () {
      const r = JourneyRewards(earnedDay: 5, tipOffer: TipOffer.declined);
      expect(
        fillPicks(
          r,
          ranked: _rank(const []),
          weeklyTips: false,
          calmKeys: const {},
        ),
        r,
      );
    });

    test('stored picks stay when the ranking changes', () {
      const r = JourneyRewards(
        earnedDay: 3,
        picks: {1: RecipePick(id: 'a', title: 'Apfel-Reis')},
        tipOffer: TipOffer.declined,
      );
      final next = fillPicks(
        r,
        ranked: _rank([_c, _b]),
        weeklyTips: false,
        calmKeys: const {},
      );
      expect(next.picks, {
        1: const RecipePick(id: 'a', title: 'Apfel-Reis'),
        3: const RecipePick(id: 'c', title: 'Couscous-Salat'),
      });
    });
  });

  group('pickJourneyRecipe', () {
    test('only excluded or no recipes: null', () {
      expect(pickJourneyRecipe(const []), isNull);
      expect(pickJourneyRecipe(_rank([_a]).fits, exclude: {'a'}), isNull);
    });

    test('a kritisch recipe still comes when nothing else is left', () {
      expect(
        pickJourneyRecipe(_rank([_a, _b]).fits, exclude: {'a'}),
        const RecipePick(id: 'b', title: 'Bananenbrot'),
      );
    });
  });

  group('picksMissing', () {
    const pick = RecipePick(id: 'x', title: 'X');

    test('while a recipe day has no pick, earned or not', () {
      expect(picksMissing(const JourneyRewards()), isTrue);
      expect(
        picksMissing(
          const JourneyRewards(earnedDay: 7, picks: {1: pick, 3: pick}),
        ),
        isTrue,
      );
      expect(
        picksMissing(const JourneyRewards(picks: {1: pick, 3: pick, 5: pick})),
        isFalse,
      );
    });

    test('day 3 not once the tip was accepted', () {
      expect(
        picksMissing(
          const JourneyRewards(
            picks: {1: pick, 5: pick},
            tipOffer: TipOffer.accepted,
          ),
        ),
        isFalse,
      );
      expect(
        picksMissing(
          const JourneyRewards(
            picks: {1: pick, 5: pick},
            tipOffer: TipOffer.declined,
          ),
        ),
        isTrue,
      );
    });
  });

  group('announcementDay', () {
    // Day 3: see the day-3 table.
    test('0 and 7 → null; 1, 2, 4, 5, 6 → themselves', () {
      expect(
        announcementDay(const JourneyRewards(), weeklyTips: false),
        isNull,
      );
      expect(
        announcementDay(
          const JourneyRewards(earnedDay: 7, tipOffer: TipOffer.skipped),
          weeklyTips: true,
        ),
        isNull,
      );
      for (final day in [1, 2, 4, 5, 6]) {
        expect(
          announcementDay(
            JourneyRewards(earnedDay: day, tipOffer: TipOffer.declined),
            weeklyTips: false,
          ),
          day,
        );
      }
    });
  });

  group('tipOfferDue', () {
    const offered = JourneyRewards(earnedDay: 3, tipOffer: TipOffer.offered);

    test('day 3, offered, weekly tips off → due', () {
      expect(tipOfferDue(offered, weeklyTips: false), isTrue);
      expect(
        tipOfferDue(offered.copyWith(earnedDay: 5), weeklyTips: false),
        isTrue,
      );
    });

    test('weekly null or on → not due', () {
      expect(tipOfferDue(offered, weeklyTips: null), isFalse);
      expect(tipOfferDue(offered, weeklyTips: true), isFalse);
    });

    test('answered → not due', () {
      for (final answer in [
        TipOffer.accepted,
        TipOffer.declined,
        TipOffer.skipped,
      ]) {
        expect(
          tipOfferDue(offered.copyWith(tipOffer: answer), weeklyTips: false),
          isFalse,
        );
      }
    });

    test('earned 2 → not due', () {
      expect(
        tipOfferDue(offered.copyWith(earnedDay: 2), weeklyTips: false),
        isFalse,
      );
    });
  });

  group('answerOffer', () {
    const offered = JourneyRewards(earnedDay: 3, tipOffer: TipOffer.offered);

    test('offered → accepted or declined', () {
      expect(
        answerOffer(offered, accepted: true),
        offered.copyWith(tipOffer: TipOffer.accepted),
      );
      expect(
        answerOffer(offered, accepted: false),
        offered.copyWith(tipOffer: TipOffer.declined),
      );
    });

    test('undecided or answered: itself', () {
      for (final offer in [
        null,
        TipOffer.accepted,
        TipOffer.declined,
        TipOffer.skipped,
      ]) {
        final r = JourneyRewards(earnedDay: 3, tipOffer: offer);
        for (final accepted in [true, false]) {
          expect(identical(answerOffer(r, accepted: accepted), r), isTrue);
        }
      }
    });
  });

  group('rewardEarned', () {
    test('days 1–6 up to the earned day', () {
      const r = JourneyRewards(earnedDay: 4);
      for (final day in [1, 2, 3, 4]) {
        expect(rewardEarned(day, r), isTrue, reason: '$day');
      }
      for (final day in [5, 6]) {
        expect(rewardEarned(day, r), isFalse, reason: '$day');
      }
    });

    test('day 7 only with patternsFreed', () {
      expect(rewardEarned(7, const JourneyRewards(earnedDay: 7)), isFalse);
      expect(
        rewardEarned(
          7,
          const JourneyRewards(earnedDay: 6, patternsFreed: true),
        ),
        isTrue,
      );
    });
  });

  group('rewardPick', () {
    const one = RecipePick(id: 'r-1', title: 'Eins');
    const three = RecipePick(id: 'r-3', title: 'Drei');
    const five = RecipePick(id: 'r-5', title: 'Fünf');
    const picked = JourneyRewards(
      earnedDay: 5,
      picks: {1: one, 3: three, 5: five},
      tipOffer: TipOffer.declined,
    );

    test("a recipe day's stored pick", () {
      expect(rewardPick(1, picked, weeklyTips: false), one);
      expect(rewardPick(3, picked, weeklyTips: false), three);
      expect(rewardPick(5, picked, weeklyTips: false), five);
    });

    test('none on the other days, nor without a pick', () {
      for (final day in [2, 4, 6, 7]) {
        expect(rewardPick(day, picked, weeklyTips: false), isNull);
      }
      expect(
        rewardPick(5, const JourneyRewards(earnedDay: 5), weeklyTips: false),
        isNull,
      );
    });
  });

  group('day 3: one rule (day3Of) for every site', () {
    const three = RecipePick(id: 'r-3', title: 'Drei');
    const tip = 'Dein erster Tipp', recipe = 'Ein Rezept für dich';

    // Day 3 earned, its recipe picked. Per offer and weekly tips: the rule,
    // the title, whether the pick is the reward, whether the offer is due,
    // whether the Buddy announces it, and whether a missing pick is made.
    for (final (offer, weekly, day3, title, shown, due, announced, fills) in [
      (null, false, Day3.waiting, tip, false, false, false, false),
      (null, null, Day3.waiting, tip, false, false, false, false),
      // Only before day 3: advanceRewards decides the offer once the
      // weekly tips are known.
      (null, true, Day3.recipe, recipe, true, false, false, true),
      (TipOffer.offered, false, Day3.offerOpen, tip, false, true, false, true),
      (TipOffer.offered, null, Day3.offerOpen, tip, false, false, false, true),
      (TipOffer.offered, true, Day3.recipe, recipe, true, false, false, true),
      for (final weekly in [false, null, true]) ...[
        (TipOffer.accepted, weekly, Day3.tip, tip, false, false, false, false),
        (
          TipOffer.declined,
          weekly,
          Day3.recipe,
          recipe,
          true,
          false,
          false,
          true,
        ),
        (
          TipOffer.skipped,
          weekly,
          Day3.recipe,
          recipe,
          true,
          false,
          true,
          true,
        ),
      ],
    ]) {
      test('${offer?.name}, weekly tips $weekly → ${day3.name}', () {
        final r = JourneyRewards(
          earnedDay: 3,
          picks: const {3: three},
          tipOffer: offer,
        );
        expect(day3Of(r, weeklyTips: weekly), day3);
        expect(rewardTitle(3, r, weeklyTips: weekly), title);
        expect(rewardPick(3, r, weeklyTips: weekly), shown ? three : isNull);
        expect(tipOfferDue(r, weeklyTips: weekly), due);
        expect(announcementDay(r, weeklyTips: weekly), announced ? 3 : isNull);
        final filled = fillPicks(
          JourneyRewards(earnedDay: 3, tipOffer: offer),
          ranked: _rank([_a, _c]),
          calmKeys: const {},
          weeklyTips: weekly,
        );
        expect(filled.picks.containsKey(3), fills);
      });
    }

    test('offered before day 3 is earned: waiting, never due', () {
      const early = JourneyRewards(earnedDay: 2, tipOffer: TipOffer.offered);
      expect(day3Of(early, weeklyTips: false), Day3.waiting);
      expect(tipOfferDue(early, weeklyTips: false), isFalse);
    });

    test('the other days never depend on it', () {
      const one = RecipePick(id: 'r-1', title: 'Eins');
      const accepted = JourneyRewards(
        earnedDay: 5,
        picks: {1: one, 3: three},
        tipOffer: TipOffer.accepted,
      );
      expect(rewardPick(1, accepted, weeklyTips: false), one);
    });
  });

  group('rewardTitle', () {
    test('the other days: their constant', () {
      const r = JourneyRewards(earnedDay: 7);
      expect(
        [
          for (final day in [1, 2, 4, 6, 7])
            rewardTitle(day, r, weeklyTips: null),
        ],
        [
          'Dein erstes Rezept',
          'Ein Wissen-Häppchen',
          'Ein Spruch von mir',
          'Eine Vorschau auf deine Muster',
          'Deine ersten Muster',
        ],
      );
    });

    test('day 5 claims the ingredients only once a matched pick is stored', () {
      String title(JourneyRewards r) => rewardTitle(5, r, weeklyTips: false);
      expect(
        title(const JourneyRewards(earnedDay: 4)),
        'Noch ein Rezept für dich',
        reason: 'before day 5',
      );
      expect(
        title(const JourneyRewards(earnedDay: 5, picks: _earlier)),
        'Noch ein Rezept für dich',
        reason: 'earned without a pick',
      );
      expect(
        title(
          const JourneyRewards(
            earnedDay: 5,
            picks: {5: RecipePick(id: 'x', title: 'Kartoffelsuppe')},
          ),
        ),
        'Noch ein Rezept für dich',
        reason: 'a generic pick',
      );
      expect(
        title(
          const JourneyRewards(
            earnedDay: 5,
            picks: {
              5: RecipePick(id: 'y', title: 'Reispfanne', matched: ['Reis']),
            },
          ),
        ),
        'Ein Rezept mit deinen Zutaten',
        reason: 'a matched pick',
      );
    });
  });

  group('rewardLine', () {
    String? line(
      int earned, {
      required List<JourneyDay> journey,
      int gutFeelings = 1,
      bool? weeklyTips = false,
      DateTime? today,
    }) => rewardLine(
      JourneyRewards(earnedDay: earned),
      insights: lockedInsights(
        activeDays: journey.length,
        gutFeelings: gutFeelings,
        journey: journey,
      ),
      today: today ?? _today,
      weeklyTips: weeklyTips,
    );

    test('no entry yet', () {
      expect(
        line(0, journey: const [], gutFeelings: 0),
        'Heute wartet: Dein erstes Rezept',
      );
    });

    test('day 2 filled today', () {
      expect(
        line(2, journey: _journeyUntil(_today, 2)),
        'Heute: Ein Wissen-Häppchen',
      );
    });

    test('day 4 yesterday: day 5 waits without claiming a match', () {
      expect(
        line(4, journey: _journeyUntil(_yesterday, 4)),
        'Heute wartet: Noch ein Rezept für dich',
      );
    });

    test('day 2 yesterday, none today', () {
      final journey = _journeyUntil(_yesterday, 2);
      expect(line(2, journey: journey), 'Heute wartet: Dein erster Tipp');
      expect(
        line(2, journey: journey, weeklyTips: true),
        'Heute wartet: Ein Rezept für dich',
      );
    });

    test('a late-evening entry on the DST Sunday is today', () {
      expect(
        line(
          2,
          journey: [
            JourneyDay(DateTime(2026, 10, 24), gutFeeling: false),
            JourneyDay(DateTime(2026, 10, 25), gutFeeling: false),
          ],
          // The day of a 23:45 clock on that Sunday ([todayProvider]).
          today: startOfDay(DateTime(2026, 10, 25, 23, 45)),
        ),
        'Heute: Ein Wissen-Häppchen',
      );
    });

    test('day 6 filled', () {
      expect(
        line(6, journey: _journeyUntil(_today, 6), gutFeelings: 3),
        'Heute: Eine Vorschau auf deine Muster',
      );
    });

    test('day 6 yesterday, Bauchgefühl complete', () {
      expect(
        line(6, journey: _journeyUntil(_yesterday, 6), gutFeelings: 3),
        'Heute wartet: Deine ersten Muster',
      );
    });

    test('day 6 yesterday, one Bauchgefühl missing', () {
      expect(
        line(6, journey: _journeyUntil(_yesterday, 6), gutFeelings: 2),
        'Bald: Deine ersten Muster',
      );
    });

    test('unlocked: none', () {
      expect(
        line(7, journey: _journeyUntil(_today, 7), gutFeelings: 3),
        isNull,
      );
    });

    test('day 7 locked', () {
      expect(
        line(7, journey: _journeyUntil(_today, 7), gutFeelings: 2),
        'Bald: Deine ersten Muster',
      );
    });
  });

  group('sayingFor', () {
    test('the same id twice → the same saying', () {
      expect(sayingFor('user-1'), sayingFor('user-1'));
    });

    test('different ids → different sayings', () {
      expect(sayingFor('u1'), isNot(sayingFor('u2')));
    });

    test('always one of the sayings', () {
      expect(JourneyCopy.sayings, hasLength(6));
      for (final id in ['', 'u1', 'u2', 'a-very-long-user-id-0123456789']) {
        expect(JourneyCopy.sayings, contains(sayingFor(id)));
      }
    });
  });

  group('JourneyCopy', () {
    test('day 5 names the matched lines', () {
      expect(
        JourneyCopy.day5Because(['Karotte', 'Reis']),
        'Mit Karotte und Reis: Die hast du an Tagen ohne schlechtes '
        'Bauchgefühl gegessen.',
      );
    });

    test('day 6 counts the missing Bauchgefühl entries', () {
      expect(
        JourneyCopy.day6Line(2),
        'Noch ein Tag und 2× Bauchgefühl, dann schau ich nach deinen ersten '
        'Mustern.',
      );
      expect(
        JourneyCopy.day6Line(0),
        'Noch ein Tag, dann schau ich nach deinen ersten Mustern.',
      );
    });
  });
}
