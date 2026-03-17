import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:belly_buddy/utils/date_format_utils.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE', null);
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

  group('last7Days', () {
    test('subtracts 7 days from explicit date', () {
      final now = DateTime(2026, 3, 13);
      final result = last7Days(now);
      expect(result, DateTime(2026, 3, 6));
    });

    test('handles month boundary', () {
      final now = DateTime(2026, 3, 3);
      final result = last7Days(now);
      expect(result, DateTime(2026, 2, 24));
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
}
