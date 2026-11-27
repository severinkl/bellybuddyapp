import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/models/progress.dart';
import 'package:belly_buddy/services/progress/progress_copy.dart';
import 'package:belly_buddy/utils/date_format_utils.dart';

/// A week of [monday] with the given counts; [elapsed] days up to today.
ProgressWeek week({
  int good = 0,
  int medium = 0,
  int hard = 0,
  int active = 0,
  int elapsed = 7,
  DateTime? monday,
}) {
  final m = monday ?? DateTime(2026, 11, 16);
  return ProgressWeek(
    monday: m,
    days: [
      for (var i = 0; i < 7; i++)
        ProgressDay(
          day: addDays(m, i),
          dayClass: DayClass.none,
          active: false,
          future: i >= elapsed,
        ),
    ],
    good: good,
    medium: medium,
    hard: hard,
    activeDays: active,
    elapsedDays: elapsed,
  );
}

ProgressDay day(DayClass c, {bool active = true}) => ProgressDay(
  day: DateTime(2026, 11, 18),
  dayClass: c,
  active: active,
  future: false,
);

void main() {
  test('fixed copy', () {
    expect(ProgressCopy.title, 'Dein Verlauf');
    expect(ProgressCopy.meSubtitle, 'Wie es dir über die Wochen geht');
    expect(
      ProgressCopy.patternsLink,
      'Deinen Verlauf über 12 Wochen ansehen ›',
    );
    expect(ProgressCopy.header, 'Die letzten 12 Wochen');
    expect(
      ProgressCopy.moreGoodDays,
      'Letzte Woche hattest du mehr gute Tage als die Woche davor.',
    );
    expect(ProgressCopy.currentStreak, 'Aktueller Streak');
    expect(ProgressCopy.longestStreak, 'Längster Streak');
    expect(ProgressCopy.longestSub, 'in den letzten 12 Wochen');
    expect(ProgressCopy.noGutFeelingLegend, 'ohne Bauchgefühl');
    expect(ProgressCopy.emptyTitle, 'Dein Verlauf füllt sich bald');
    expect(
      ProgressCopy.emptyBody,
      'Trag dein Bauchgefühl ein – dann siehst du hier Woche für Woche, wie '
      'es dir geht.',
    );
    expect(ProgressCopy.emptyAction, 'Bauchgefühl eintragen');
    expect(ProgressCopy.loadError, 'Dein Verlauf konnte nicht geladen werden.');
    expect(ProgressCopy.retry, 'Nochmal versuchen');
  });

  test('classTotal: noun for good days, adjective for the others', () {
    expect(ProgressCopy.classTotal(DayClass.good, 34), '34 gute Tage');
    expect(ProgressCopy.classTotal(DayClass.good, 1), '1 guter Tag');
    expect(ProgressCopy.classTotal(DayClass.good, 0), '0 gute Tage');
    expect(ProgressCopy.classTotal(DayClass.medium, 12), '12 mittlere');
    expect(ProgressCopy.classTotal(DayClass.medium, 1), '1 mittlerer');
    expect(ProgressCopy.classTotal(DayClass.hard, 6), '6 schwere');
    expect(ProgressCopy.classTotal(DayClass.hard, 1), '1 schwerer');
  });

  test('streakDays', () {
    expect(ProgressCopy.streakDays(0), 'Startet mit deinem nächsten Eintrag');
    expect(ProgressCopy.streakDays(1), '1 Tag');
    expect(ProgressCopy.streakDays(5), '5 Tage');
  });

  test('loggedTotal', () {
    expect(ProgressCopy.loggedTotal(61, 84), 'Eingetragen an 61 von 84 Tagen');
  });

  test('weekLabel', () {
    final today = DateTime(2026, 11, 26, 10);
    expect(
      ProgressCopy.weekLabel(DateTime(2026, 11, 23), today),
      'Diese Woche',
    );
    expect(
      ProgressCopy.weekLabel(DateTime(2025, 11, 17), today),
      '17.–23. Nov',
    );
    expect(
      ProgressCopy.weekLabel(DateTime(2025, 10, 27), today),
      '27. Okt – 2. Nov',
    );
    expect(
      ProgressCopy.weekLabel(DateTime(2025, 12, 29), today),
      '29. Dez – 4. Jan',
    );
  });

  test('weekCounts: zero classes left out, order good, medium, hard', () {
    expect(
      ProgressCopy.weekCounts(week(good: 5, hard: 1)),
      '5 gute Tage, 1 schwerer',
    );
    expect(
      ProgressCopy.weekCounts(week(good: 1, medium: 2)),
      '1 guter Tag, 2 mittlere',
    );
    expect(
      ProgressCopy.weekCounts(week(good: 2, medium: 1, hard: 3)),
      '2 gute Tage, 1 mittlerer, 3 schwere',
    );
    // Without good days the first part still carries the noun.
    expect(
      ProgressCopy.weekCounts(week(medium: 2, hard: 1)),
      '2 mittlere Tage, 1 schwerer',
    );
    expect(ProgressCopy.weekCounts(week(medium: 1)), '1 mittlerer Tag');
    expect(ProgressCopy.weekCounts(week(hard: 4)), '4 schwere Tage');
    expect(
      ProgressCopy.weekCounts(week(active: 3)),
      'Kein Bauchgefühl eingetragen',
    );
  });

  test('weekLogged', () {
    expect(
      ProgressCopy.weekLogged(week(active: 6)),
      ' · an 6 von 7 Tagen eingetragen',
    );
    expect(
      ProgressCopy.weekLogged(week(active: 0, elapsed: 3)),
      ' · an 0 von 3 Tagen eingetragen',
    );
    expect(
      ProgressCopy.weekLogged(week(active: 1, elapsed: 1)),
      ' · heute eingetragen',
    );
    expect(
      ProgressCopy.weekLogged(week(active: 0, elapsed: 1)),
      ' · heute noch nichts eingetragen',
    );
  });

  test('daySemantics', () {
    expect(ProgressCopy.daySemantics(day(DayClass.good)), '18. Nov: gut');
    expect(ProgressCopy.daySemantics(day(DayClass.medium)), '18. Nov: mittel');
    expect(ProgressCopy.daySemantics(day(DayClass.hard)), '18. Nov: schwer');
    expect(
      ProgressCopy.daySemantics(day(DayClass.none)),
      '18. Nov: eingetragen, ohne Bauchgefühl',
    );
    expect(
      ProgressCopy.daySemantics(day(DayClass.none, active: false)),
      '18. Nov: kein Eintrag',
    );
  });

  group('trendSemantics', () {
    SymptomMeans m(double v) =>
        SymptomMeans(bloating: v, gas: v, cramps: v, fullness: v);

    /// [n] weeks, oldest first, the last one the current; [means] by index.
    List<ProgressWeek> weeks(int n, Map<int, SymptomMeans> means) => [
      for (var i = 0; i < n; i++)
        ProgressWeek(
          monday: addDays(DateTime(2026, 11, 23), (i - n + 1) * 7),
          days: const [],
          good: 0,
          medium: 0,
          hard: 0,
          activeDays: 0,
          elapsedDays: 7,
          means: means[i],
        ),
    ];

    test('names newest and oldest week with means, German comma', () {
      final w = weeks(12, {
        0: const SymptomMeans(bloating: 3.1, gas: 1, cramps: 1, fullness: 1),
        11: const SymptomMeans(bloating: 2.3, gas: 1, cramps: 1, fullness: 1),
      });
      expect(
        ProgressCopy.trendSemantics('Blähbauch', w),
        'Blähbauch: diese Woche im Schnitt 2,3 von 5; vor 11 Wochen 3,1',
      );
    });

    test('last week and 5 weeks ago', () {
      final w = weeks(12, {
        6: const SymptomMeans(bloating: 1, gas: 1, cramps: 2.5, fullness: 1),
        10: const SymptomMeans(bloating: 1, gas: 1, cramps: 1.0, fullness: 1),
      });
      expect(
        ProgressCopy.trendSemantics('Krämpfe', w),
        'Krämpfe: letzte Woche im Schnitt 1,0 von 5; vor 5 Wochen 2,5',
      );
    });

    test('one week with means has no "vor" part; none says too few', () {
      expect(
        ProgressCopy.trendSemantics('Blähungen', weeks(12, {11: m(2)})),
        'Blähungen: diese Woche im Schnitt 2,0 von 5',
      );
      expect(
        ProgressCopy.trendSemantics('Blähungen', weeks(12, {})),
        'Blähungen: zu wenig Einträge',
      );
    });
  });
}
