import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/insight_source.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/services/insights/insights_engine.dart';

final now = DateTime(2026, 11, 23, 20);

DateTime oct(int day, [int hour = 12, int minute = 0]) =>
    DateTime(2026, 10, day, hour, minute);
DateTime nov(int day, [int hour = 12, int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

InsightMeal meal(DateTime at, List<String> ingredients) =>
    InsightMeal(trackedAt: at, ingredients: ingredients);

var _ids = 0;

/// A gut-feeling entry with all four symptoms at [v], so its score is [v].
GutFeelingEntry gut(DateTime at, int v) => GutFeelingEntry(
  id: 'g${_ids++}',
  trackedAt: at,
  bloating: v,
  gas: v,
  cramps: v,
  fullness: v,
);

/// A gut-feeling entry with each gut symptom given (1 = none) and every
/// mood value at [mood] (null = not set).
GutFeelingEntry symptoms(
  DateTime at, {
  int bloating = 1,
  int gas = 1,
  int cramps = 1,
  int fullness = 1,
  int? mood,
}) => GutFeelingEntry(
  id: 's${_ids++}',
  trackedAt: at,
  bloating: bloating,
  gas: gas,
  cramps: cramps,
  fullness: fullness,
  stress: mood,
  happiness: mood,
  energy: mood,
  focus: mood,
  bodyFeel: mood,
);

Insights compute({
  List<InsightMeal> meals = const [],
  List<GutFeelingEntry> guts = const [],
  List<DateTime> activity = const [],
  DateTime? at,
}) => computeInsights(
  InsightSource(meals: meals, gutFeelings: guts, activityInstants: activity),
  at ?? now,
);

/// One hard (5) entry at 12:00 per [hard] day from 1 Nov, one good (1) entry
/// per [good] day from 12 Nov, each after a meal at 08:00 that morning with
/// the day's ingredients. No meal reaches another day's window.
Insights fromDays({
  List<List<String>> hard = const [],
  List<List<String>> good = const [],
}) {
  assert(hard.length <= 11 && good.length <= 12);
  return compute(
    meals: [
      for (var i = 0; i < hard.length; i++) meal(nov(1 + i, 8), hard[i]),
      for (var i = 0; i < good.length; i++) meal(nov(12 + i, 8), good[i]),
    ],
    guts: [
      for (var i = 0; i < hard.length; i++) gut(nov(1 + i), 5),
      for (var i = 0; i < good.length; i++) gut(nov(12 + i), 1),
    ],
  );
}

/// [days] lists of ingredients: each ingredient is on the first `count` days.
List<List<String>> spread(int days, Map<String, int> counts) => [
  for (var d = 0; d < days; d++)
    [
      for (final e in counts.entries)
        if (d < e.value) e.key,
    ],
];

/// Two more hard days (3 and 5 Nov) with [ingredients] eaten that morning.
/// With one more hard day and no good day (H = 3, G = 0), every ingredient
/// there on 2 hard days shows up in `noticed`, with `hard == 3` exactly when
/// the third day had it too.
List<InsightMeal> twoHardDayMeals(List<String> ingredients) => [
  meal(nov(3, 8), ingredients),
  meal(nov(5, 8), ingredients),
];
List<GutFeelingEntry> twoHardDays() => [gut(nov(3), 5), gut(nov(5), 5)];

/// `hard` per noticed ingredient name.
Map<String, int> hardCounts(Insights insights) => {
  for (final n in insights.noticed) n.name: n.hard,
};

DayClass classOn(Insights insights, DateTime day) => insights.calendar
    .firstWhere((d) => d.day == DateTime(day.year, day.month, day.day))
    .dayClass;

void main() {
  group('window and progress', () {
    test('calendar has 30 days, oldest first, today last', () {
      final calendar = compute().calendar;
      expect(calendar, hasLength(30));
      expect(calendar.first.day, DateTime(2026, 10, 25));
      expect(calendar.last.day, DateTime(2026, 11, 23));
    });

    test('progress counts distinct active days and gut entries', () {
      final insights = compute(
        activity: [
          nov(20, 8),
          nov(20, 12),
          nov(20, 18),
          nov(21),
          oct(24, 23, 59), // before the window
          nov(24, 0), // after today
        ],
        guts: [gut(nov(20), 2), gut(oct(24, 23, 59), 2), gut(nov(24, 0), 2)],
      );
      expect(
        insights.progress,
        const InsightProgress(activeDays: 2, gutFeelingEntries: 1),
      );
    });

    test('the window runs from local midnight 29 days ago through the end '
        'of today', () {
      final insights = compute(
        activity: [oct(24, 23, 59), oct(25, 0), now, nov(24, 0)],
        guts: [
          gut(oct(24, 23, 59), 5),
          gut(oct(25, 0), 1),
          gut(now, 1),
          gut(nov(23, 23, 59), 2),
          gut(nov(24, 0), 5),
        ],
      );
      expect(
        insights.progress,
        const InsightProgress(activeDays: 2, gutFeelingEntries: 3),
      );
      expect(insights.calendar.first.dayClass, DayClass.good);
      // The entry after today does not make today's mean 8/3 (medium).
      expect(insights.calendar.last.dayClass, DayClass.good);
    });

    test('an entry logged for later today counts now', () {
      // At 18:00 the 3rd gut-feeling entry is logged for 21:00.
      final at = nov(23, 18);
      final insights = compute(
        activity: [for (var d = 17; d <= 22; d++) nov(d), nov(23, 21)],
        guts: [gut(nov(20), 2), gut(nov(21), 2), gut(nov(23, 21), 5)],
        at: at,
      );
      expect(
        insights.progress,
        const InsightProgress(activeDays: 7, gutFeelingEntries: 3),
      );
      expect(insights.unlocked, isTrue);
      expect(insights.calendar.last.day, DateTime(2026, 11, 23));
      expect(insights.calendar.last.dayClass, DayClass.hard);
    });

    test('unlocks with 7 active days and 3 gut entries', () {
      final guts = [gut(nov(1), 2), gut(nov(2), 2), gut(nov(3), 2)];
      final sixDays = [for (var d = 1; d <= 6; d++) nov(d)];
      expect(compute(activity: sixDays, guts: guts).unlocked, isFalse);
      expect(
        compute(activity: [...sixDays, nov(7)], guts: guts).unlocked,
        isTrue,
      );
      expect(
        compute(
          activity: [...sixDays, nov(7)],
          guts: guts.take(2).toList(),
        ).unlocked,
        isFalse,
      );
    });

    test('UTC instants count on their local day', () {
      // Just after local midnight: in any zone east of UTC this is still
      // the previous day in UTC.
      final justAfterMidnight = DateTime(2026, 11, 23, 0, 30).toUtc();
      final justBefore = DateTime(2026, 11, 22, 23, 30).toUtc();
      final insights = compute(
        activity: [justBefore, justAfterMidnight],
        guts: [gut(justAfterMidnight, 5)],
        at: now.toUtc(),
      );
      expect(insights.progress.activeDays, 2);
      expect(insights.calendar.last.day, DateTime(2026, 11, 23));
      expect(insights.calendar.last.dayClass, DayClass.hard);
      expect(classOn(insights, nov(22)), DayClass.none);
    });

    test('the calendar steps calendar days across the DST switch', () {
      // 25 Oct 2026, the window's first day, has 25 hours in Europe.
      final insights = compute(
        guts: [gut(oct(25, 23, 30), 5), gut(oct(26, 0, 30), 1)],
      );
      expect(insights.calendar.map((d) => d.day), [
        for (var i = 0; i < 30; i++) DateTime(2026, 10, 25 + i),
      ]);
      expect(insights.calendar[0].dayClass, DayClass.hard);
      expect(insights.calendar[1].dayClass, DayClass.good);
    });
  });

  group('day classes', () {
    test("day class from the mean of the day's entries' scores", () {
      final insights = compute(
        guts: [
          gut(nov(10, 9), 2),
          gut(nov(10, 18), 3), // 2.5 → good
          gut(nov(11, 9), 3),
          gut(nov(11, 18), 4), // 3.5 → medium
          gut(nov(12, 9), 4),
          gut(nov(12, 18), 4), // 4 → hard
        ],
      );
      expect(classOn(insights, nov(10)), DayClass.good);
      expect(classOn(insights, nov(11)), DayClass.medium);
      expect(classOn(insights, nov(12)), DayClass.hard);
      expect(classOn(insights, nov(13)), DayClass.none);
      expect(insights.gutFeelingDays, 3);
      expect(insights.goodDays.days, 1);
      expect(insights.hardDays.days, 1);
    });

    test('a mean of exactly 2.5 is good, just above is medium', () {
      List<GutFeelingEntry> day(int d, List<int> scores) => [
        for (var i = 0; i < scores.length; i++) gut(nov(d, 8 + i), scores[i]),
      ];
      final insights = compute(
        guts: [
          ...day(1, [2, 3]), // 5/2
          ...day(2, [1, 1, 3, 5]), // 10/4
          ...day(3, [2, 2, 3]), // 7/3
          ...day(4, [2, 3, 3]), // 8/3
          ...day(5, [3, 3, 3, 2, 2, 2]), // 15/6
          ...day(6, [3, 3, 3, 3, 2, 2, 2]), // 18/7
        ],
      );
      expect(classOn(insights, nov(1)), DayClass.good);
      expect(classOn(insights, nov(2)), DayClass.good);
      expect(classOn(insights, nov(3)), DayClass.good);
      expect(classOn(insights, nov(4)), DayClass.medium);
      expect(classOn(insights, nov(5)), DayClass.good);
      expect(classOn(insights, nov(6)), DayClass.medium);
    });

    test('a mean of exactly 3.5 is medium, just above is hard', () {
      List<GutFeelingEntry> day(int d, List<int> scores) => [
        for (var i = 0; i < scores.length; i++) gut(nov(d, 8 + i), scores[i]),
      ];
      final insights = compute(
        guts: [
          ...day(1, [2, 5]), // 7/2
          ...day(2, [1, 5, 5, 3]), // 14/4
          ...day(3, [3, 4, 3]), // 10/3
          ...day(4, [4, 4, 3]), // 11/3
          ...day(5, [4, 4, 4, 3, 3, 3]), // 21/6
          ...day(6, [4, 4, 4, 4, 3, 3, 3]), // 25/7
        ],
      );
      expect(classOn(insights, nov(1)), DayClass.medium);
      expect(classOn(insights, nov(2)), DayClass.medium);
      expect(classOn(insights, nov(3)), DayClass.medium);
      expect(classOn(insights, nov(4)), DayClass.hard);
      expect(classOn(insights, nov(5)), DayClass.medium);
      expect(classOn(insights, nov(6)), DayClass.hard);
    });

    test('an entry counts with its worst gut symptom', () {
      // Krämpfe 5 and Völlegefühl 5 with no Blähbauch or Blähungen.
      final insights = compute(
        guts: [symptoms(nov(10), cramps: 5, fullness: 5)],
      );
      expect(classOn(insights, nov(10)), DayClass.hard);
      expect(insights.hardDays.days, 1);
    });

    test('the mood never counts', () {
      final insights = compute(
        guts: [
          symptoms(nov(10, 9), mood: 5),
          symptoms(nov(10, 18), mood: 5),
          symptoms(nov(11), mood: 1, gas: 4),
        ],
      );
      expect(classOn(insights, nov(10)), DayClass.good);
      expect(classOn(insights, nov(11)), DayClass.hard);
    });

    test('a day with a 1 and a 5 is medium (mean 3)', () {
      final insights = compute(
        guts: [symptoms(nov(10, 9)), symptoms(nov(10, 18), bloating: 5)],
      );
      expect(classOn(insights, nov(10)), DayClass.medium);
      expect(insights.goodDays.days, 0);
      expect(insights.hardDays.days, 0);
    });
  });

  group('24 h windows', () {
    test('hard anchor is the first schlecht entry, not the first entry', () {
      // 10 Nov: a 3 at 08:00, then a 5 at 12:00 → mean 4, anchor 12:00.
      final insights = compute(
        guts: [...twoHardDays(), gut(nov(10, 8), 3), gut(nov(10, 12), 5)],
        meals: [
          ...twoHardDayMeals(['A', 'B', 'C', 'D', 'E']),
          meal(nov(10, 10), ['A']), // after the 08:00 entry, before 12:00
          meal(nov(10, 11, 59), ['B']), // 1 min before the anchor
          meal(nov(10, 12), ['C']), // at the anchor: excluded
          meal(nov(9, 12), ['D']), // exactly 24 h before: included
          meal(nov(9, 11, 59), ['E']), // 24 h 1 min before: excluded
        ],
      );
      expect(hardCounts(insights), {'A': 3, 'B': 3, 'D': 3, 'C': 2, 'E': 2});
    });

    test('a bad mood does not make the hard anchor', () {
      // 10 Nov: at 08:00 every symptom 3 with every mood value 5 (score 3),
      // at 12:00 Krämpfe 5 (score 5) → mean 4, anchor 12:00.
      final insights = compute(
        guts: [
          ...twoHardDays(),
          symptoms(
            nov(10, 8),
            bloating: 3,
            gas: 3,
            cramps: 3,
            fullness: 3,
            mood: 5,
          ),
          symptoms(nov(10, 12), cramps: 5),
        ],
        meals: [
          ...twoHardDayMeals(['A', 'B']),
          meal(nov(10, 7), ['A']), // before both entries
          meal(nov(10, 10), ['B']), // after the 08:00 entry, before 12:00
        ],
      );
      expect(hardCounts(insights), {'A': 3, 'B': 3});
    });

    test('good anchor is the first gut/sehr gut entry', () {
      // 15 Nov: a 4 at 08:00, 1 at 12:00, 1 at 14:00 → mean 2, anchor 12:00.
      final insights = compute(
        guts: [
          gut(nov(17), 1),
          gut(nov(19), 1),
          gut(nov(15, 8), 4),
          gut(nov(15, 12), 1),
          gut(nov(15, 14), 1),
        ],
        meals: [
          meal(nov(17, 8), ['Hafer', 'Reis']),
          meal(nov(19, 8), ['Hafer', 'Reis']),
          meal(nov(15, 10), ['Hafer']), // inside the 12:00 window
          meal(nov(15, 13), ['Reis']), // after the anchor
        ],
      );
      expect(insights.goodDays.often, const [
        IngredientCount('Hafer', 3, of: 3),
        IngredientCount('Reis', 2, of: 3),
      ]);
    });

    test('window reaches into the previous day', () {
      final insights = compute(
        guts: [...twoHardDays(), gut(nov(10, 7), 5)],
        meals: [
          ...twoHardDayMeals(['Zwiebel', 'Brot']),
          meal(nov(9, 21), ['Zwiebel']),
          meal(nov(9, 6), ['Brot']), // 25 h before
        ],
      );
      expect(hardCounts(insights), {'Zwiebel': 3, 'Brot': 2});
    });

    test("window reaches into the day before the window's first day", () {
      final insights = compute(
        guts: [...twoHardDays(), gut(oct(25, 7), 5)],
        meals: [
          ...twoHardDayMeals(['Zwiebel', 'Brot']),
          meal(oct(24, 21), ['Zwiebel']),
          meal(oct(24, 6), ['Brot']), // more than 24 h before
        ],
      );
      expect(insights.calendar.first.dayClass, DayClass.hard);
      expect(hardCounts(insights), {'Zwiebel': 3, 'Brot': 2});
    });

    test('the window is 24 real hours across the DST switch', () {
      // In Europe, 24 h before 25 Oct 12:00 CET is 24 Oct 13:00 CEST, not
      // the same clock time the day before.
      final anchor = oct(25, 12);
      final insights = compute(
        guts: [...twoHardDays(), gut(anchor, 5)],
        meals: [
          ...twoHardDayMeals(['Drin', 'Draussen']),
          meal(anchor.subtract(const Duration(hours: 24)), ['Drin']),
          meal(anchor.subtract(const Duration(hours: 24, minutes: 1)), [
            'Draussen',
          ]),
        ],
      );
      expect(hardCounts(insights), {'Drin': 3, 'Draussen': 2});
    });

    test("a later-today entry's window ends at its own time", () {
      // At 18:00, a hard entry logged for 21:00: the meals before it count,
      // also those logged for later today; one after it does not.
      final insights = compute(
        guts: [...twoHardDays(), gut(nov(23, 21), 5)],
        meals: [
          ...twoHardDayMeals(['Früh', 'Später', 'Danach']),
          meal(nov(23, 12), ['Früh']),
          meal(nov(23, 19), ['Später']), // later today, before the anchor
          meal(nov(23, 21, 30), ['Danach']), // after the anchor
        ],
        at: nov(23, 18),
      );
      expect(hardCounts(insights), {'Früh': 3, 'Später': 3, 'Danach': 2});
    });

    test("a meal in two days' windows counts on both", () {
      final insights = compute(
        guts: [gut(nov(9, 21), 5), gut(nov(10, 19), 5), gut(nov(11), 5)],
        meals: [
          meal(nov(9, 20), ['Reis']),
          meal(nov(11, 8), ['Reis']),
        ],
      );
      expect(hardCounts(insights), {'Reis': 3});
    });
  });

  group('ingredients', () {
    test('ingredient matching ignores case and spaces', () {
      final insights = compute(
        guts: [gut(nov(3), 5), gut(nov(5), 5), gut(nov(7), 5)],
        // Out of order on purpose: the most recent meal (by time, not by
        // position) names it, even outside every window and not after today.
        meals: [
          meal(nov(7, 8), ['Zwiebel']),
          meal(nov(23, 21), [' zwiebel ']), // most recent, later today
          meal(nov(5, 8), [' zwiebel ']),
          meal(nov(24, 0), ['ZWIEBEL']), // after today: ignored
          meal(nov(3, 8), ['ZWIEBEL']),
        ],
      );
      expect(insights.noticed, const [
        Noticed(name: 'zwiebel', hard: 3, hardDays: 3, good: 0, goodDays: 0),
      ]);
    });

    test('one meal counts once per day', () {
      final insights = compute(
        guts: [...twoHardDays(), gut(nov(10), 5)],
        meals: [
          ...twoHardDayMeals(['Zwiebel']),
          meal(nov(10, 8), ['Zwiebel', 'zwiebel ']),
          meal(nov(10, 9), ['Zwiebel']),
        ],
      );
      expect(hardCounts(insights), {'Zwiebel': 3});
    });

    test('blank ingredient names are skipped', () {
      final insights = fromDays(hard: spread(3, {'': 3, '   ': 3}));
      expect(insights.noticed, isEmpty);
      expect(insights.hardDays.often, isEmpty);
    });
  });

  group('Fällt mir auf', () {
    test('thresholds (H = 5, G = 6)', () {
      final insights = fromDays(
        hard: spread(5, {
          'Zwiebel': 4,
          'Knoblauch': 3,
          'Kaffee': 3,
          'Brot': 3,
          'Milch': 2,
        }),
        good: spread(6, {'Zwiebel': 1, 'Knoblauch': 1, 'Kaffee': 3, 'Brot': 2}),
      );
      expect(insights.noticed, const [
        // rate 0.8, gap 0.633
        Noticed(name: 'Zwiebel', hard: 4, hardDays: 5, good: 1, goodDays: 6),
        // 0.6, 0.433
        Noticed(name: 'Knoblauch', hard: 3, hardDays: 5, good: 1, goodDays: 6),
        // 0.6, 0.267. Kaffee: gap 0.1. Milch: rate 0.4.
        Noticed(name: 'Brot', hard: 3, hardDays: 5, good: 2, goodDays: 6),
      ]);
    });

    test('uncertain needs hard == 2 and the rates', () {
      final insights = fromDays(
        hard: spread(4, {'Apfel': 2, 'Birne': 2}),
        good: spread(2, {'Birne': 1}),
      );
      expect(insights.noticed, const [
        // rate 0.5, gap 0.5. Birne: gap 0.
        Noticed(
          name: 'Apfel',
          hard: 2,
          hardDays: 4,
          good: 0,
          goodDays: 2,
          uncertain: true,
        ),
      ]);
    });

    test('no section below 3 hard days', () {
      final insights = fromDays(
        hard: spread(2, {'Zwiebel': 2}),
        good: spread(5, {}),
      );
      expect(insights.noticed, isEmpty);
    });

    test('G == 0 uses gap = rate', () {
      final insights = fromDays(hard: spread(3, {'Reis': 3}));
      expect(insights.noticed, const [
        Noticed(name: 'Reis', hard: 3, hardDays: 3, good: 0, goodDays: 0),
      ]);
    });

    test('a rate of exactly 0.5 counts, just below does not', () {
      expect(hardCounts(fromDays(hard: spread(6, {'Reis': 3}))), {'Reis': 3});
      expect(fromDays(hard: spread(7, {'Reis': 3})).noticed, isEmpty);
    });

    test('a gap of exactly 0.25 counts, also with thirds and twelfths', () {
      // 3/4 − 2/4 = 0.25; 3/4 − 3/4 = 0.
      expect(
        hardCounts(
          fromDays(
            hard: spread(4, {'Reis': 3, 'Hafer': 3}),
            good: spread(4, {'Reis': 2, 'Hafer': 3}),
          ),
        ),
        {'Reis': 3},
      );
      // H = 6: 4/6 − 5/12, H = 3: 2/3 − 5/12; as doubles both make
      // 0.24999999999999994.
      expect(
        hardCounts(
          fromDays(hard: spread(6, {'Reis': 4}), good: spread(12, {'Reis': 5})),
        ),
        {'Reis': 4},
      );
      expect(
        fromDays(
          hard: spread(3, {'Reis': 2}),
          good: spread(12, {'Reis': 5}),
        ).noticed.single.uncertain,
        isTrue,
      );
    });

    test('sorted by hard, then gap, then name', () {
      final insights = fromDays(
        hard: spread(5, {
          'Birne': 3,
          'apfel': 3,
          'Zimt': 3,
          'Senf': 4,
          'Dill': 4,
        }),
        good: spread(5, {'Birne': 1, 'apfel': 1, 'Senf': 2}),
      );
      expect(insights.noticed.map((n) => n.name), [
        'Dill', // 4, gap 0.8
        'Senf', // 4, gap 0.4
        'Zimt', // 3, gap 0.6
        'apfel', // 3, gap 0.4, names compared without case
        'Birne', // 3, gap 0.4
      ]);
    });

    test('ties sort by name in German order', () {
      final insights = fromDays(
        hard: spread(3, {'Zwiebel': 3, 'Äpfel': 3, 'Öl': 3, 'Brot': 3}),
      );
      expect(insights.noticed.map((n) => n.name), [
        'Äpfel',
        'Brot',
        'Öl',
        'Zwiebel',
      ]);
    });

    test('top 5 shown, then top 3 uncertain', () {
      final insights = fromDays(
        hard: spread(4, {
          'Okra': 2,
          'Nuss': 2,
          'Mais': 2,
          'Lauch': 2,
          'Kiwi': 3,
          'Gurke': 3,
          'Feige': 3,
          'Dattel': 3,
          'Birne': 3,
          'Apfel': 3,
          'Zwiebel': 4,
        }),
      );
      expect(insights.noticed.map((n) => (n.name, n.uncertain)), [
        ('Zwiebel', false),
        ('Apfel', false),
        ('Birne', false),
        ('Dattel', false),
        ('Feige', false),
        ('Lauch', true),
        ('Mais', true),
        ('Nuss', true),
      ]);
    });
  });

  group('columns', () {
    test('hidden below 3 days, and then without items', () {
      final insights = fromDays(good: spread(2, {'Reis': 2}));
      expect(insights.goodDays, const DayColumn(days: 2));
      expect(insights.goodDays.shown, isFalse);
      expect(insights.hardDays, const DayColumn(days: 0));
    });

    test('oft dabei on at least 2 days and at least half of them', () {
      final four = fromDays(
        good: spread(4, {'Karotte': 1, 'Hafer': 2, 'Reis': 3}),
      );
      expect(four.goodDays.shown, isTrue);
      expect(four.goodDays.often, const [
        IngredientCount('Reis', 3, of: 4),
        IngredientCount('Hafer', 2, of: 4),
      ]);

      final five = fromDays(good: spread(5, {'Hafer': 2, 'Reis': 3}));
      expect(five.goodDays.often, const [IngredientCount('Reis', 3, of: 5)]);
    });

    test('at most 5, by count, then name', () {
      final insights = fromDays(
        good: spread(6, {
          'Feige': 3,
          'Ei': 3,
          'Dill': 3,
          'Birne': 3,
          'apfel': 3,
          'Senf': 4,
          'Reis': 6,
        }),
      );
      expect(insights.goodDays.often, const [
        IngredientCount('Reis', 6, of: 6),
        IngredientCount('Senf', 4, of: 6),
        IngredientCount('apfel', 3, of: 6),
        IngredientCount('Birne', 3, of: 6),
        IngredientCount('Dill', 3, of: 6),
      ]);
    });

    test('ties sort by name in German order: Ä with A, ahead of Z', () {
      // By code unit, „Äpfel" sorts after „Zwiebel" and falls out of the
      // top 5.
      final insights = fromDays(
        good: spread(3, {
          'Zwiebel': 3,
          'Feige': 3,
          'Ei': 3,
          'Dill': 3,
          'Birne': 3,
          'Äpfel': 3,
        }),
      );
      expect(insights.goodDays.often.map((i) => i.name), [
        'Äpfel',
        'Birne',
        'Dill',
        'Ei',
        'Feige',
      ]);
    });

    test('a name with an umlaut sorts next to its plain spelling, the same '
        'way every time', () {
      final names = [
        'Muesli',
        'Möhre',
        'Mohn',
        'Mus',
        'Müsli',
        'Maße',
        'Masse',
      ];
      for (final order in [names, names.reversed.toList()]) {
        final insights = fromDays(
          good: spread(3, {for (final n in order) n: 3}),
        );
        expect(
          insights.goodDays.often.map((i) => i.name),
          // ß as ss; on equal folds („Masse"/„Maße") the plain one first.
          ['Masse', 'Maße', 'Mohn', 'Möhre', 'Muesli'],
          reason: 'input order $order',
        );
      }
    });

    test('the hard column counts hard days', () {
      final insights = fromDays(hard: spread(5, {'Zwiebel': 4, 'Brot': 2}));
      expect(
        insights.hardDays,
        const DayColumn(days: 5, often: [IngredientCount('Zwiebel', 4, of: 5)]),
      );
    });
  });

  group('pick', () {
    test('the top shown item, ahead of a good-days column', () {
      final insights = fromDays(
        hard: spread(5, {'Zwiebel': 4, 'Brot': 3}),
        good: spread(6, {'Zwiebel': 1, 'Kaffee': 3}),
      );
      expect(insights.goodDays.often, isNotEmpty);
      expect(
        insights.pick,
        const NoticedPick(
          Noticed(name: 'Zwiebel', hard: 4, hardDays: 5, good: 1, goodDays: 6),
        ),
      );
    });

    test('otherwise the good days, also when only uncertain items exist', () {
      final insights = fromDays(
        hard: spread(4, {'Apfel': 2}),
        good: spread(3, {'Reis': 3}),
      );
      expect(insights.noticed.single.uncertain, isTrue);
      expect(
        insights.pick,
        const GoodDaysPick(
          DayColumn(days: 3, often: [IngredientCount('Reis', 3, of: 3)]),
        ),
      );
    });

    test('otherwise nothing yet', () {
      expect(
        fromDays(good: spread(3, {'Reis': 1})).pick,
        const NothingYetPick(),
      );
      expect(
        fromDays(good: spread(2, {'Reis': 2})).pick,
        const NothingYetPick(),
      );
    });
  });

  test('empty source: nothing yet, 30 days without entries', () {
    final insights = compute();
    final expected = Insights(
      progress: const InsightProgress(activeDays: 0, gutFeelingEntries: 0),
      calendar: [
        for (var i = 0; i < 30; i++)
          InsightDay(day: DateTime(2026, 10, 25 + i), dayClass: DayClass.none),
      ],
      goodDays: const DayColumn(days: 0),
      hardDays: const DayColumn(days: 0),
      noticed: const [],
      pick: const NothingYetPick(),
    );
    expect(insights, expected);
    expect(insights.hashCode, expected.hashCode);
    expect(insights.unlocked, isFalse);
    expect(insights.gutFeelingDays, 0);
  });

  test('results are unmodifiable values', () {
    final insights = fromDays(hard: spread(3, {'Reis': 3}));
    expect(() => insights.noticed.clear(), throwsUnsupportedError);
    expect(() => insights.calendar.clear(), throwsUnsupportedError);
    expect(() => insights.hardDays.often.clear(), throwsUnsupportedError);
    expect(insights, fromDays(hard: spread(3, {'Reis': 3})));
    expect(insights, isNot(fromDays(hard: spread(3, {'Reis': 2}))));
  });
}
