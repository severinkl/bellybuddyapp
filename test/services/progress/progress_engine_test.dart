import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/models/progress.dart';
import 'package:belly_buddy/models/progress_rules.dart';
import 'package:belly_buddy/services/progress/progress_engine.dart';
import 'package:belly_buddy/utils/date_format_utils.dart';
import 'package:belly_buddy/utils/wall_clock.dart';

/// Thursday of the week of 23 Nov 2026.
final now = DateTime(2026, 11, 26, 10);

DateTime sep(int day, [int hour = 12]) => DateTime(2026, 9, day, hour);
DateTime oct(int day, [int hour = 12]) => DateTime(2026, 10, day, hour);
DateTime nov(int day, [int hour = 12]) => DateTime(2026, 11, day, hour);

var _ids = 0;

/// A gut-feeling entry with all four symptoms at [v], so its score is [v].
GutFeelingEntry gut(DateTime at, int v, {int? stress}) => GutFeelingEntry(
  id: 'g${_ids++}',
  trackedAt: at,
  bloating: v,
  gas: v,
  cramps: v,
  fullness: v,
  stress: stress,
);

/// A gut-feeling entry with each gut symptom given (1 = none).
GutFeelingEntry symptoms(
  DateTime at, {
  int bloating = 1,
  int gas = 1,
  int cramps = 1,
  int fullness = 1,
  int? stress,
}) => GutFeelingEntry(
  id: 's${_ids++}',
  trackedAt: at,
  bloating: bloating,
  gas: gas,
  cramps: cramps,
  fullness: fullness,
  stress: stress,
);

({DateTime trackedAt, int stoolType}) klo(DateTime at, int stoolType) =>
    (trackedAt: at, stoolType: stoolType);

Progress compute({
  List<GutFeelingEntry> guts = const [],
  List<({DateTime trackedAt, int stoolType})> toilets = const [],
  List<DateTime> other = const [],
  Set<DateTime> savedDays = const {},
}) => computeProgress(
  ProgressSource(gutFeelings: guts, toilets: toilets, otherTimes: other),
  now: now,
  savedDays: savedDays,
);

ProgressDay dayOf(Progress p, DateTime day) =>
    p.weeks.expand((w) => w.days).singleWhere((d) => d.day == startOfDay(day));

ProgressWeek weekOf(Progress p, DateTime monday) =>
    p.weeks.singleWhere((w) => w.monday == monday);

void main() {
  test('window is 12 Monday weeks ending this week', () {
    final p = compute(guts: [gut(nov(27), 1)], other: [nov(28)]);
    expect(p.weeks, hasLength(ProgressRules.weeks));
    expect(p.weeks.first.monday, DateTime(2026, 9, 7));
    expect(p.weeks.last.monday, DateTime(2026, 11, 23));
    for (final (i, w) in p.weeks.indexed) {
      expect(w.monday, addDays(DateTime(2026, 9, 7), 7 * i));
      expect(w.days, hasLength(7));
    }
    final last = p.weeks.last;
    expect(
      [for (final d in last.days) d.future],
      [false, false, false, false, true, true, true],
    );
    expect(last.elapsedDays, 4);
    // Entries after today are never counted.
    expect(last.days.every((d) => !d.active), isTrue);
    expect(last.days.every((d) => d.dayClass == DayClass.none), isTrue);
    expect(last.gutFeelingEntries, 0);
    expect(p.weeks.take(11).every((w) => w.elapsedDays == 7), isTrue);
    // Today counts.
    final today = compute(guts: [gut(nov(26, 23), 1)]);
    expect(dayOf(today, nov(26)).active, isTrue);
    expect(dayOf(today, nov(26)).dayClass, DayClass.good);
  });

  test('day class equals the Muster', () {
    final p = compute(
      guts: [
        gut(nov(2), 2),
        gut(nov(2, 18), 3),
        gut(nov(3), 3),
        gut(nov(3), 4),
      ],
    );
    expect(dayOf(p, nov(2)).dayClass, DayClass.good);
    expect(dayOf(p, nov(3)).dayClass, DayClass.medium);

    final file =
        jsonDecode(
              File('test/fixtures/insights/vectors.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final first = DateTime(2026, 9, 7);
    var checked = 0;
    for (final v in (file['vectors'] as List).cast<Map<String, dynamic>>()) {
      final guts = [
        for (final (i, g) in (v['gut_feelings'] as List).indexed)
          GutFeelingEntry(
            id: 'v$i',
            trackedAt: wallClockFromWire(g['tracked_at'] as String),
            bloating: g['bloating'] as int,
            gas: g['gas'] as int,
            cramps: g['cramps'] as int,
            fullness: g['fullness'] as int,
          ),
      ];
      final progress = compute(guts: guts);
      final calendar = v['expected']['calendar'] as Map<String, dynamic>;
      final classes = calendar['classes'] as Map<String, dynamic>;
      var day = DateTime.parse(calendar['first_day'] as String);
      final lastDay = DateTime.parse(calendar['last_day'] as String);
      for (; !day.isAfter(lastDay); day = addDays(day, 1)) {
        if (day.isBefore(first) || day.isAfter(nov(26))) continue;
        expect(
          dayOf(progress, day).dayClass.name,
          classes[formatIsoDate(day)] ?? DayClass.none.name,
          reason: '${v['id']} ${formatIsoDate(day)}',
        );
        checked++;
      }
    }
    expect(checked, greaterThan(0));
  });

  test('wall-clock day and DST week', () {
    final p = compute(guts: [gut(DateTime.utc(2026, 10, 25, 23, 30), 5)]);
    expect(dayOf(p, oct(25)).dayClass, DayClass.hard);
    expect(dayOf(p, oct(25)).active, isTrue);
    expect(dayOf(p, oct(26)).active, isFalse);

    final week = weekOf(p, DateTime(2026, 10, 19));
    expect(
      [for (final d in week.days) d.day],
      [for (var i = 0; i < 7; i++) DateTime(2026, 10, 19 + i)],
    );
    expect(week.days.map((d) => d.day).toSet(), hasLength(7));
    expect(week.hard, 1);
    expect(week.elapsedDays, 7);
  });

  test('activeDays counts any table', () {
    final p = compute(
      toilets: [klo(nov(9), 3)],
      other: [nov(10), nov(10, 18)],
      guts: [gut(nov(11), 1)],
    );
    expect(dayOf(p, nov(9)).active, isTrue);
    expect(dayOf(p, nov(9)).dayClass, DayClass.none);
    expect(dayOf(p, nov(10)).active, isTrue);
    expect(dayOf(p, nov(10)).dayClass, DayClass.none);
    expect(dayOf(p, nov(12)).active, isFalse);
    final week = weekOf(p, DateTime(2026, 11, 9));
    expect(week.activeDays, 3);
    expect(week.good, 1);
    expect(week.gutFeelingEntries, 1);
    expect(p.activeDays, 3);
  });

  test('means need 3 entries on 2 days', () {
    final oneDay = compute(
      guts: [gut(nov(2), 2), gut(nov(2), 3), gut(nov(2), 5)],
    );
    expect(weekOf(oneDay, DateTime(2026, 11, 2)).means, isNull);
    expect(weekOf(oneDay, DateTime(2026, 11, 2)).gutFeelingEntries, 3);

    final twoEntries = compute(guts: [gut(nov(2), 2), gut(nov(3), 3)]);
    expect(weekOf(twoEntries, DateTime(2026, 11, 2)).means, isNull);

    final twoDays = compute(
      guts: [
        symptoms(nov(2), bloating: 2, gas: 1, cramps: 4, fullness: 1),
        symptoms(nov(2, 18), bloating: 3, gas: 2, cramps: 4, fullness: 1),
        symptoms(nov(4), bloating: 5, gas: 2, cramps: 1, fullness: 1),
      ],
    );
    expect(
      weekOf(twoDays, DateTime(2026, 11, 2)).means,
      const SymptomMeans(bloating: 10 / 3, gas: 5 / 3, cramps: 3, fullness: 1),
    );
    expect(weekOf(twoDays, DateTime(2026, 11, 9)).means, isNull);
    expect(twoDays.showTrend, isFalse);

    final twoWeeks = compute(
      guts: [
        gut(nov(2), 1),
        gut(nov(3), 1),
        gut(nov(3), 1),
        gut(nov(9), 1),
        gut(nov(10), 1),
        gut(nov(10), 1),
      ],
    );
    expect(twoWeeks.showTrend, isTrue);
  });

  test('totals and elapsed days', () {
    final p = compute(
      guts: [
        gut(sep(7, 0), 1),
        gut(oct(1), 3),
        gut(oct(2), 5),
        gut(oct(3), 5),
        gut(nov(26), 2),
      ],
      other: [sep(8), oct(1)],
    );
    expect(p.elapsedDays, 81);
    expect(p.elapsedDays, 11 * 7 + 4);
    expect(p.good, 2);
    expect(p.medium, 1);
    expect(p.hard, 2);
    expect(p.activeDays, 6);
    expect(p.good, p.weeks.fold<int>(0, (s, w) => s + w.good));
    expect(p.medium, p.weeks.fold<int>(0, (s, w) => s + w.medium));
    expect(p.hard, p.weeks.fold<int>(0, (s, w) => s + w.hard));
    expect(p.activeDays, p.weeks.fold<int>(0, (s, w) => s + w.activeDays));
    expect(p.isEmpty, isFalse);

    // The day before the window and days after today are not counted.
    final outside = compute(guts: [gut(sep(6, 23), 1), gut(nov(27), 1)]);
    expect(outside.isEmpty, isTrue);
    expect(outside.good, 0);
  });

  test('longest streak counts saved days and spans weeks', () {
    final p = compute(
      other: [nov(15), nov(17), nov(2)],
      savedDays: {DateTime(2026, 11, 16)},
    );
    expect(p.longestStreak, 3);
    // Saved days alone do not make the day active.
    expect(dayOf(p, nov(16)).active, isFalse);
    expect(p.activeDays, 3);

    final run = compute(
      guts: [gut(oct(30), 1)],
      toilets: [klo(oct(31), 3)],
      other: [nov(1), nov(2), nov(20)],
    );
    expect(run.longestStreak, 4);
    expect(compute().longestStreak, 0);
  });

  test('moreGoodDaysLastWeek only with 3 rated days in both weeks', () {
    // weeks[9] = 9–15 Nov, weeks[10] = 16–22 Nov.
    final more = compute(
      guts: [
        gut(nov(9), 1),
        gut(nov(10), 1),
        gut(nov(11), 5),
        gut(nov(16), 1),
        gut(nov(17), 1),
        gut(nov(18), 1),
      ],
    );
    expect(more.weeks[9].rated, 3);
    expect(more.weeks[10].rated, 3);
    expect(more.moreGoodDaysLastWeek, isTrue);

    final same = compute(
      guts: [
        gut(nov(9), 1),
        gut(nov(10), 1),
        gut(nov(11), 1),
        gut(nov(16), 1),
        gut(nov(17), 1),
        gut(nov(18), 1),
      ],
    );
    expect(same.moreGoodDaysLastWeek, isFalse);

    final fewBefore = compute(
      guts: [
        gut(nov(9), 5),
        gut(nov(10), 1),
        gut(nov(16), 1),
        gut(nov(17), 1),
        gut(nov(18), 1),
      ],
    );
    expect(fewBefore.weeks[9].rated, 2);
    expect(fewBefore.moreGoodDaysLastWeek, isFalse);

    final fewLast = compute(
      guts: [
        gut(nov(9), 5),
        gut(nov(10), 5),
        gut(nov(11), 5),
        gut(nov(16), 1),
        gut(nov(17), 1),
      ],
    );
    expect(fewLast.moreGoodDaysLastWeek, isFalse);
  });

  test(
    'recent: last 7 days only; symptom means need 3 entries; klo counts hard 1–2 and loose 4–5',
    () {
      final p = compute(
        guts: [
          symptoms(nov(19), bloating: 5, stress: 5),
          symptoms(nov(20, 0), bloating: 3, stress: 4),
          symptoms(nov(23), bloating: 4, gas: 2),
          symptoms(nov(26, 23), bloating: 2, stress: 2),
          symptoms(nov(27), bloating: 5, stress: 5),
        ],
        toilets: [
          klo(nov(19), 1),
          klo(nov(20), 1),
          klo(nov(21), 2),
          klo(nov(22), 3),
          klo(nov(24), 4),
          klo(nov(25), 5),
          klo(nov(26), 3),
          klo(nov(27), 5),
        ],
      );
      expect(
        p.recent.means,
        const SymptomMeans(bloating: 3, gas: 4 / 3, cramps: 1, fullness: 1),
      );
      expect(p.recent.stress, isNull);
      expect(p.recent.klo, 6);
      expect(p.recent.kloHard, 2);
      expect(p.recent.kloLoose, 2);

      final stressed = compute(
        guts: [
          gut(nov(20), 1, stress: 3),
          gut(nov(21), 1, stress: 4),
          gut(nov(22), 1),
          gut(nov(26), 1, stress: 2),
        ],
      );
      expect(stressed.recent.stress, 3);

      final two = compute(guts: [gut(nov(25), 4), gut(nov(26), 4)]);
      expect(two.recent.means, isNull);
      expect(two.recent.klo, 0);
    },
  );

  test('empty source', () {
    final p = compute();
    expect(p.isEmpty, isTrue);
    expect(p.weeks, hasLength(12));
    for (final d in p.weeks.expand((w) => w.days)) {
      expect(d.dayClass, DayClass.none);
      expect(d.active, isFalse);
    }
    expect(p.weeks.every((w) => w.means == null), isTrue);
    expect(p.showTrend, isFalse);
    expect(p.moreGoodDaysLastWeek, isFalse);
    expect(p.longestStreak, 0);
    expect(p.elapsedDays, 81);
    expect(p.recent, const RecentSignals(klo: 0, kloHard: 0, kloLoose: 0));
  });
}
