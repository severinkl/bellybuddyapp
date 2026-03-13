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
}
