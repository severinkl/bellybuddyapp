import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/models/replacement_ingredient.dart';
import 'package:belly_buddy/services/daily_review/daily_review_rules.dart';
import 'package:belly_buddy/utils/gut_feeling_rating.dart';
import 'package:belly_buddy/utils/wall_clock.dart';
import 'package:flutter_test/flutter_test.dart';

const _t = 19 * 60 + 30;
final _day = DateTime(2026, 11, 26);

ReviewDay? _open(DateTime now, {DateTime? closed}) =>
    openReviewDay(now: now, reviewMinutes: _t, closedDay: closed);

MealEntry _meal(String id, DateTime at) =>
    MealEntry(id: id, trackedAt: at, title: id);

GutFeelingEntry _gut(String id, DateTime at, int v) => GutFeelingEntry(
  id: id,
  trackedAt: at,
  bloating: v,
  gas: 1,
  cramps: 1,
  fullness: 1,
);

/// `tracked_at` as production reads it: the wall clock sent in the UTC slot.
DateTime _wall(int y, int m, int d, [int h = 12, int min = 0]) =>
    wallClockFromWire(DateTime.utc(y, m, d, h, min).toIso8601String());

MealDetail _md(String id, DateTime at) =>
    MealDetail(id: id, title: id, trackedAt: at);

ReplacementIngredient _r(String id) =>
    ReplacementIngredient(id: id, name: 'R$id');

IngredientSuggestionGroup _group(
  String id,
  List<MealDetail> meals, {
  String? name,
  List<ReplacementIngredient>? replacements,
}) => IngredientSuggestionGroup(
  ingredientId: id,
  ingredientName: name ?? id,
  mealCount: meals.length,
  isNew: false,
  suggestionIds: const [],
  meals: meals,
  replacements: replacements ?? [_r('${id}1'), _r('${id}2')],
);

void main() {
  group('openReviewDay', () {
    test('19:29 → null; 19:30 → today; 23:59 → today', () {
      expect(_open(DateTime(2026, 11, 26, 19, 29)), isNull);
      final a = _open(DateTime(2026, 11, 26, 19, 30))!;
      expect(a.yesterday, isFalse);
      expect(a.day, DateTime(2026, 11, 26));
      expect(_open(DateTime(2026, 11, 26, 23, 59))!.yesterday, isFalse);
    });

    test('00:00 next day → yesterday; 10:59 → yesterday; 11:00 → null', () {
      final a = _open(DateTime(2026, 11, 27, 0, 0))!;
      expect(a.yesterday, isTrue);
      expect(a.day, DateTime(2026, 11, 26));
      expect(_open(DateTime(2026, 11, 27, 10, 59))!.yesterday, isTrue);
      expect(_open(DateTime(2026, 11, 27, 11, 0)), isNull);
    });

    test('yesterday across a month boundary', () {
      expect(_open(DateTime(2026, 12, 1, 8))!.day, DateTime(2026, 11, 30));
    });

    test('review time 09:00 is clamped to 16:00', () {
      expect(reviewMinutesOf('09:00'), 16 * 60);
      expect(reviewMinutesOf('23:45'), 23 * 60 + 30);
      expect(reviewMinutesOf('19:30'), _t);
      expect(reviewMinutesOf('abc'), _t);
      expect(reviewMinutesOf(null), _t);
      expect(reviewMinutesOf('25:00'), _t);
      expect(reviewMinutesOf('18:05:00'), 18 * 60 + 5);
    });

    test('closed today/yesterday', () {
      expect(
        _open(DateTime(2026, 11, 26, 20), closed: DateTime(2026, 11, 26)),
        isNull,
      );
      final closedYesterday = DateTime(2026, 11, 26);
      expect(_open(DateTime(2026, 11, 27, 8), closed: closedYesterday), isNull);
      expect(
        _open(DateTime(2026, 11, 27, 19, 30), closed: closedYesterday),
        isNotNull,
      );
    });
  });

  group('onWallClockDay / buildDailyReview', () {
    test('wall-clock day fields decide', () {
      expect(onWallClockDay(_wall(2026, 11, 26, 23, 30), _day), isTrue);
      expect(onWallClockDay(_wall(2026, 11, 27, 0, 10), _day), isFalse);
    });

    DailyReview? build(
      List<MealEntry> meals, [
      List<GutFeelingEntry> guts = const [],
    ]) => buildDailyReview(
      day: ReviewDay(_day, yesterday: false),
      meals: meals,
      gutFeelings: guts,
      groups: const [],
      chosen: const {},
    );

    test('no meal that day → null; 1 meal → meals 1', () {
      expect(build([_meal('a', _wall(2026, 11, 27, 0, 10))]), isNull);
      expect(build([_meal('a', _wall(2026, 11, 26, 23, 30))])!.meals, 1);
    });

    test(
      'lastGut is the level of the latest entry of the day; none → null',
      () {
        final meals = [_meal('a', _wall(2026, 11, 26, 8))];
        expect(build(meals)!.lastGut, isNull);
        final r = build(meals, [
          _gut('g1', _wall(2026, 11, 26, 9), 5),
          _gut('g2', _wall(2026, 11, 26, 18), 1),
          _gut('g3', _wall(2026, 11, 27, 1), 5),
        ])!;
        expect(r.lastGut, GutFeelingRatingLevel.spiGut);
      },
    );
  });

  group('buildDailyReview wiring', () {
    final today = _md('today', _wall(2026, 11, 26, 12));
    final other = _md('other-day', _wall(2026, 11, 25, 12));
    final meals = [
      _meal('today', _wall(2026, 11, 26, 12)),
      _meal('other-day', _wall(2026, 11, 25, 12)),
    ];

    DailyReview review({
      List<IngredientSuggestionGroup>? groups,
      bool locked = false,
      bool pending = false,
      List<DailyReviewLine> extras = const [],
    }) => buildDailyReview(
      day: ReviewDay(_day, yesterday: false),
      meals: meals,
      gutFeelings: const [],
      groups:
          groups ??
          [
            _group('a', [today]),
          ],
      chosen: const {},
      alternativeLocked: locked,
      alternativePending: pending,
      extras: extras,
    )!;

    test('only the review day\'s meals count and pick', () {
      expect(review().meals, 1);
      // A group only on the other day's meal: no pick.
      expect(
        review(
          groups: [
            _group('b', [other]),
          ],
        ).alternative,
        isNull,
      );
      expect(review().alternative!.group.ingredientId, 'a');
    });

    test('alternativeLocked and extras pass through; locked keeps the '
        'pick', () {
      const extras = [DailyReviewLine('x', route: '/x')];
      final r = review(locked: true, extras: extras);
      expect(r.alternativeLocked, isTrue);
      expect(r.extras, same(extras));
      expect(r.alternative, isNotNull);
      expect(review().alternativeLocked, isFalse);
    });

    test('no groups → no pick, not pending', () {
      final r = review(groups: const []);
      expect(r.alternative, isNull);
      expect(r.alternativePending, isFalse);
    });

    test('pending → no pick yet, though there is one', () {
      final r = review(pending: true);
      expect(r.alternative, isNull);
      expect(r.alternativePending, isTrue);
    });
  });

  group('pickAlternative', () {
    AlternativePick? pick(
      List<IngredientSuggestionGroup> groups, {
      Set<String> ids = const {'today'},
      Set<(String, String)> chosen = const {},
    }) => pickAlternative(
      groups: groups,
      dayMealIds: ids,
      chosen: chosen,
      day: _day,
    );

    final today = _md('today', _wall(2026, 11, 26, 12));

    test('only groups with a meal of the day are candidates', () {
      final other = _group('x', [_md('old', _wall(2026, 11, 25))]);
      expect(pick([other]), isNull);
      final a = _group('a', [today]);
      expect(pick([other, a])!.group.ingredientId, 'a');
    });

    test('more meals in the last 14 days wins', () {
      final a = _group('a', [today]);
      final b = _group('b', [today, _md('m2', _wall(2026, 11, 20))]);
      final p = pick([a, b])!;
      expect(p.group.ingredientId, 'b');
      expect(p.recentMeals, 2);
    });

    test('14-day boundary: day-13 counts, day-14 does not; later days no', () {
      // review day 26 Nov: window is 13 Nov .. 26 Nov.
      final inside = _group('in', [today, _md('e', _wall(2026, 11, 13, 0, 0))]);
      final outside = _group('out', [
        today,
        _md('e2', _wall(2026, 11, 12, 23, 59)),
      ]);
      expect(pick([inside])!.recentMeals, 2);
      expect(pick([outside])!.recentMeals, 1);
      final after = _group('after', [
        today,
        _md('f', _wall(2026, 11, 27, 0, 5)),
      ]);
      expect(pick([after])!.recentMeals, 1);
      expect(pick([outside, inside])!.group.ingredientId, 'in');
    });

    test('tie → latest meal; tie → name ignoring case', () {
      final late = _md('late', _wall(2026, 11, 26, 20));
      final a = _group('a', [today]);
      final b = _group('b', [late]);
      expect(pick([a, b], ids: {'today', 'late'})!.group.ingredientId, 'b');
      final zed = _group('zed', [today], name: 'Zwiebel');
      final apf = _group('apf', [today], name: 'apfel');
      expect(pick([zed, apf])!.group.ingredientName, 'apfel');
    });

    test(
      'a chosen replacement is skipped; the next of the group is picked',
      () {
        final a = _group('a', [today]);
        final p = pick([a], chosen: {('a', 'a1')})!;
        expect(p.replacement.id, 'a2');
      },
    );

    test('all replacements of the top group chosen → the next group', () {
      final a = _group('a', [today, _md('m', _wall(2026, 11, 20))]);
      final b = _group('b', [today]);
      final p = pick([a, b], chosen: {('a', 'a1'), ('a', 'a2')})!;
      expect(p.group.ingredientId, 'b');
    });

    test(
      'groups without replacements are never picked; nothing left → null',
      () {
        final a = _group('a', [today], replacements: const []);
        expect(pick([a]), isNull);
        final b = _group('b', [today]);
        expect(pick([b], chosen: {('b', 'b1'), ('b', 'b2')}), isNull);
      },
    );
  });
}
