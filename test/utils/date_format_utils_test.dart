import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:belly_buddy/utils/date_format_utils.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE', null);
  });

  group('addDays', () {
    test('steps calendar days, at midnight, across month ends', () {
      expect(
        addDays(DateTime(2026, 11, 22, 14, 30), -1),
        DateTime(2026, 11, 21),
      );
      expect(addDays(DateTime(2026, 11, 30), 1), DateTime(2026, 12, 1));
      expect(addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
      expect(addDays(DateTime(2026, 11, 22), 0), DateTime(2026, 11, 22));
    });

    test('lands on the calendar day across DST switches', () {
      // Spring forward (Europe: 29 Mar 2026) and fall back (25 Oct 2026).
      final spring = addDays(DateTime(2026, 3, 28), 2);
      expect((spring.year, spring.month, spring.day), (2026, 3, 30));
      expect(spring.hour, 0);
      final fall = addDays(DateTime(2026, 10, 26), -2);
      expect((fall.year, fall.month, fall.day), (2026, 10, 24));
      expect(fall.hour, 0);
    });
  });

  group('mondayOf', () {
    test("the week's Monday at midnight, across a month end", () {
      // 23 Nov 2026 is a Monday.
      expect(mondayOf(DateTime(2026, 11, 23, 9)), DateTime(2026, 11, 23));
      expect(mondayOf(DateTime(2026, 11, 29, 23, 59)), DateTime(2026, 11, 23));
      expect(mondayOf(DateTime(2026, 12, 2)), DateTime(2026, 11, 30));
    });
  });

  group('isoWeekOf', () {
    test('Monday to Sunday share one week', () {
      expect(isoWeekOf(DateTime(2026, 11, 16)), 47);
      expect(isoWeekOf(DateTime(2026, 11, 22, 23, 59)), 47);
      expect(isoWeekOf(DateTime(2026, 11, 23)), 48);
    });

    test("days around New Year belong to their Thursday's year", () {
      // 2026 starts on a Thursday, so it has 53 weeks.
      expect(isoWeekOf(DateTime(2025, 12, 29)), 1);
      expect(isoWeekOf(DateTime(2026, 1, 1)), 1);
      expect(isoWeekOf(DateTime(2026, 12, 31)), 53);
      expect(isoWeekOf(DateTime(2027, 1, 3)), 53);
      expect(isoWeekOf(DateTime(2027, 1, 4)), 1);
      // 3 Jan 2021 (a Sunday) is still in 2020's last week.
      expect(isoWeekOf(DateTime(2021, 1, 3)), 53);
    });

    test('ignores the switch to summer time', () {
      // 29 Mar 2026: in Europe/Vienna that day has 23 hours.
      expect(isoWeekOf(DateTime(2026, 3, 29, 12)), 13);
      expect(isoWeekOf(DateTime(2026, 3, 30)), 14);
    });
  });

  group('weekday names', () {
    test('Monday first, the short forms their first two letters', () {
      expect(kWeekdayNames.first, 'Montag');
      expect(kWeekdayNames.last, 'Sonntag');
      expect(kWeekdayShortNames, ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']);
    });
  });

  group('formatIsoDate', () {
    test('zero-pads to yyyy-MM-dd and ignores the time', () {
      expect(formatIsoDate(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
      expect(formatIsoDate(DateTime(2026, 11, 22)), '2026-11-22');
      expect(formatIsoDate(DateTime(987, 1, 2)), '0987-01-02');
    });
  });

  group('formatDateTimeShort', () {
    test('formats date and time with zero-padded hours/minutes', () {
      final dt = DateTime(2026, 3, 13, 9, 5);
      expect(formatDateTimeShort(dt), '13.3.2026 09:05 Uhr');
    });

    test('formats date and time without leading zeros on day/month', () {
      final dt = DateTime(2026, 1, 2, 14, 30);
      expect(formatDateTimeShort(dt), '2.1.2026 14:30 Uhr');
    });
  });

  group('formatDateLong', () {
    test('formats date in German locale', () {
      final dt = DateTime(2026, 3, 13);
      expect(formatDateLong(dt), '13. März 2026');
    });

    test('formats January correctly', () {
      final dt = DateTime(2026, 1, 1);
      expect(formatDateLong(dt), '1. Januar 2026');
    });
  });

  group('formatTime', () {
    test('formats time as HH:mm', () {
      final dt = DateTime(2026, 1, 1, 14, 30);
      expect(formatTime(dt), '14:30');
    });

    test('formats midnight correctly', () {
      final dt = DateTime(2026, 1, 1, 0, 0);
      expect(formatTime(dt), '00:00');
    });
  });

  group('formatDateTimeFull', () {
    test('formats with weekday in German', () {
      // 2026-03-13 is a Friday
      final dt = DateTime(2026, 3, 13, 14, 30);
      expect(formatDateTimeFull(dt), 'Freitag, 13.03.2026 14:30 Uhr');
    });
  });

  group('startOfDay', () {
    test('returns midnight for given date', () {
      final dt = DateTime(2026, 3, 13, 14, 30, 45);
      final result = startOfDay(dt);
      expect(result, DateTime(2026, 3, 13));
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
    });

    test('preserves date components', () {
      final dt = DateTime(2025, 12, 31, 23, 59, 59);
      final result = startOfDay(dt);
      expect(result.year, 2025);
      expect(result.month, 12);
      expect(result.day, 31);
    });
  });

  group('endOfDay', () {
    test('returns next midnight', () {
      final dt = DateTime(2026, 3, 13, 14, 30);
      final result = endOfDay(dt);
      expect(result, DateTime(2026, 3, 14));
    });

    test('handles month boundary', () {
      final dt = DateTime(2026, 1, 31);
      final result = endOfDay(dt);
      expect(result, DateTime(2026, 2, 1));
    });

    test('handles year boundary', () {
      final dt = DateTime(2025, 12, 31);
      final result = endOfDay(dt);
      expect(result, DateTime(2026, 1, 1));
    });
  });

  group('formatAnalysisDateRange', () {
    test('produces correct German range string', () {
      final dt = DateTime(2026, 3, 13);
      final result = formatAnalysisDateRange(dt);
      expect(result, contains('Analysiert:'));
      expect(result, contains('\u2013')); // en dash
      expect(result, contains('2026'));
    });

    test('range spans 7 days', () {
      final dt = DateTime(2026, 3, 13);
      final result = formatAnalysisDateRange(dt);
      // Start = March 6, End = March 13
      expect(result, contains('6.'));
      expect(result, contains('13.'));
    });
  });

  group('formatDateWeekday', () {
    test('formats with weekday name and date', () {
      // 2026-03-13 is a Friday
      final dt = DateTime(2026, 3, 13);
      expect(formatDateWeekday(dt), 'Freitag 13.03.2026');
    });

    test('formats Monday correctly', () {
      // 2026-03-09 is a Monday
      final dt = DateTime(2026, 3, 9);
      expect(formatDateWeekday(dt), 'Montag 09.03.2026');
    });
  });

  group('formatDateWeekdayShort', () {
    test('formats with full weekday + dd.MM (no year, no trailing dot)', () {
      // 2026-03-13 is a Friday
      final dt = DateTime(2026, 3, 13);
      expect(formatDateWeekdayShort(dt), 'Freitag, 13.03');
    });

    test('zero-pads day and month', () {
      final dt = DateTime(2026, 1, 5);
      expect(formatDateWeekdayShort(dt), 'Montag, 05.01');
    });
  });

  group('formatDateShort', () {
    test('formats as dd.MM.yyyy', () {
      final dt = DateTime(2026, 3, 13);
      expect(formatDateShort(dt), '13.03.2026');
    });

    test('zero-pads day and month', () {
      final dt = DateTime(2026, 1, 5);
      expect(formatDateShort(dt), '05.01.2026');
    });
  });

  group('isSameDay', () {
    test('same day returns true', () {
      expect(isSameDay(DateTime(2026, 3, 13), DateTime(2026, 3, 13)), true);
    });

    test('different day returns false', () {
      expect(isSameDay(DateTime(2026, 3, 13), DateTime(2026, 3, 14)), false);
    });

    test('same day different time returns true', () {
      expect(
        isSameDay(DateTime(2026, 3, 13, 8, 0), DateTime(2026, 3, 13, 22, 30)),
        true,
      );
    });

    test('different month returns false', () {
      expect(isSameDay(DateTime(2026, 3, 13), DateTime(2026, 4, 13)), false);
    });
  });

  group('buildTrackedAt', () {
    test('null initialDate → now', () {
      final now = DateTime(2026, 11, 23, 9, 41);
      expect(buildTrackedAt(null, now: now), now);
    });

    test('null without now stays within the current now() window', () {
      final before = DateTime.now();
      final result = buildTrackedAt(null);
      final after = DateTime.now();
      expect(result.isAtSameMomentAs(before) || result.isAfter(before), isTrue);
      expect(result.isAtSameMomentAs(after) || result.isBefore(after), isTrue);
    });

    test('today keeps the current clock time', () {
      final now = DateTime(2026, 11, 23, 9, 41);
      expect(
        buildTrackedAt(DateTime(2026, 11, 23), now: now),
        DateTime(2026, 11, 23, 9, 41),
      );
    });

    test('a past day defaults to 12:00', () {
      final now = DateTime(2026, 11, 23, 9, 41);
      expect(
        buildTrackedAt(DateTime(2026, 11, 18, 22, 5), now: now),
        DateTime(2026, 11, 18, 12),
      );
    });

    test('is idempotent', () {
      final now = DateTime(2026, 11, 23, 9, 41);
      final once = buildTrackedAt(DateTime(2026, 11, 18), now: now);
      expect(buildTrackedAt(once, now: now), once);
    });
  });

  test('formatLogTargetDay', () {
    expect(formatLogTargetDay(DateTime(2026, 11, 18)), 'Mi, 18. Nov');
    expect(formatLogTargetDay(DateTime(2026, 3, 2)), 'Mo, 2. Mär');
  });
}
