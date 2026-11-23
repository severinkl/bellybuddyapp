import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/services/insights/insight_copy.dart';

InsightProgress _progress(int days, int gutFeelings) =>
    InsightProgress(activeDays: days, gutFeelingEntries: gutFeelings);

DayColumn _good(int days, List<String> names) => DayColumn(
  days: days,
  often: [for (final n in names) IngredientCount(n, 2, of: days)],
);

const _zwiebel = Noticed(
  name: 'Zwiebel',
  hard: 4,
  hardDays: 5,
  good: 1,
  goodDays: 6,
);

void main() {
  group('lockedLine', () {
    test('days left first, plural and singular', () {
      expect(
        InsightCopy.lockedLine(_progress(2, 1)),
        'Noch 5 Tage, dann zeig ich dir erste Muster.',
      );
      expect(
        InsightCopy.lockedLine(_progress(6, 3)),
        'Noch 1 Tag, dann zeig ich dir erste Muster.',
      );
    });

    test('then gut-feeling entries, plural and singular', () {
      expect(
        InsightCopy.lockedLine(_progress(9, 1)),
        'Noch 2 Bauchgefühl-Einträge, dann zeig ich dir erste Muster.',
      );
      expect(
        InsightCopy.lockedLine(_progress(7, 2)),
        'Noch 1 Bauchgefühl-Eintrag, dann zeig ich dir erste Muster.',
      );
    });
  });

  group('Fällt mir auf', () {
    test('headline', () {
      expect(
        InsightCopy.noticedHeadline(_zwiebel),
        'Zwiebel war an 4 von 5 schweren Tagen dabei.',
      );
    });

    test('good line, and without good days', () {
      expect(InsightCopy.noticedGood(_zwiebel), 'an guten Tagen: 1 von 6');
      expect(
        InsightCopy.noticedGood(
          const Noticed(
            name: 'Zwiebel',
            hard: 3,
            hardDays: 3,
            good: 0,
            goodDays: 0,
          ),
        ),
        'an guten Tagen: noch keine',
      );
    });

    test('page row, and without good days', () {
      expect(
        InsightCopy.noticedRow(_zwiebel),
        'Zwiebel · an 4 von 5 schweren Tagen dabei · an guten Tagen: 1 von 6',
      );
      expect(
        InsightCopy.noticedRow(
          const Noticed(
            name: 'Knoblauch',
            hard: 2,
            hardDays: 4,
            good: 0,
            goodDays: 0,
            uncertain: true,
          ),
        ),
        'Knoblauch · an 2 von 4 schweren Tagen dabei · '
        'an guten Tagen: noch keine',
      );
    });
  });

  group('good days', () {
    test('summary joins with commas and „und" before the last', () {
      expect(
        InsightCopy.goodDaysLine(_good(6, ['Haferflocken', 'Reis', 'Karotte'])),
        "An guten Tagen gab's oft Haferflocken, Reis und Karotte.",
      );
      expect(
        InsightCopy.goodDaysLine(_good(4, ['Reis', 'Karotte'])),
        "An guten Tagen gab's oft Reis und Karotte.",
      );
      expect(
        InsightCopy.goodDaysLine(_good(3, ['Reis'])),
        "An guten Tagen gab's oft Reis.",
      );
    });

    test('sub line counts the good days of the last 30', () {
      expect(
        InsightCopy.goodDaysSub(_good(6, ['Reis'])),
        '6 gute Tage in den letzten 30',
      );
    });
  });

  group('Muster page', () {
    test('calendar header, plural and singular', () {
      expect(
        InsightCopy.calendarHeader(21),
        'Letzte 30 Tage · 21 Tage mit Bauchgefühl',
      );
      expect(
        InsightCopy.calendarHeader(1),
        'Letzte 30 Tage · 1 Tag mit Bauchgefühl',
      );
    });

    test('a day reads its date and class', () {
      InsightDay day(int month, int d, DayClass c) =>
          InsightDay(day: DateTime(2026, month, d), dayClass: c);
      expect(
        InsightCopy.daySemantics(day(11, 18, DayClass.hard)),
        '18. Nov: schwer',
      );
      expect(
        InsightCopy.daySemantics(day(10, 25, DayClass.good)),
        '25. Okt: gut',
      );
      expect(
        InsightCopy.daySemantics(day(11, 3, DayClass.medium)),
        '3. Nov: mittel',
      );
      expect(
        InsightCopy.daySemantics(day(11, 1, DayClass.none)),
        '1. Nov: kein Eintrag',
      );
    });

    test('column titles, plural, singular and none', () {
      String title(int days, {required bool hard}) =>
          InsightCopy.columnTitle(DayColumn(days: days), hard: hard);
      expect(title(6, hard: false), '6 gute Tage');
      expect(title(1, hard: false), '1 guter Tag');
      expect(title(0, hard: false), '0 gute Tage');
      expect(title(5, hard: true), '5 schwere Tage');
      expect(title(1, hard: true), '1 schwerer Tag');
    });

    test('column items and too few days', () {
      const reis = IngredientCount('Reis', 3, of: 4);
      expect(
        InsightCopy.oftenRow(reis, hard: false),
        'Reis · an 3 von 4 guten Tagen',
      );
      expect(
        InsightCopy.oftenRow(reis, hard: true),
        'Reis · an 3 von 4 schweren Tagen',
      );
      expect(InsightCopy.tooFewDays(hard: false), 'Noch zu wenige gute Tage');
      expect(InsightCopy.tooFewDays(hard: true), 'Noch zu wenige schwere Tage');
    });
  });

  test('nothing yet and kein Befund', () {
    expect(
      InsightCopy.nothingYet,
      'Noch fällt mir nichts Eindeutiges auf – trag weiter ein, dann sehe ich '
      'mehr.',
    );
    expect(InsightCopy.noFinding, 'kein Befund');
  });

  test('card headers and link', () {
    expect(InsightCopy.learningTitle, 'Was ich über deinen Bauch lerne');
    expect(InsightCopy.noticedTitle, 'Fällt mir auf');
    expect(InsightCopy.goodDaysTitle, 'Deine guten Tage');
    expect(InsightCopy.patternsLink, 'Muster ›');
  });
}
