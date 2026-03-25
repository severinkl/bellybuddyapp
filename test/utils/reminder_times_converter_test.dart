import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/utils/reminder_times_converter.dart';

void main() {
  const converter = ReminderTimesConverter();

  group('ReminderTimesConverter.fromJson', () {
    test('converts list of strings as-is', () {
      final result = converter.fromJson(['07:30', '12:00', '18:30']);
      expect(result, ['07:30', '12:00', '18:30']);
    });

    test('converts legacy list of ints to HH:00 strings', () {
      final result = converter.fromJson([7, 12, 18]);
      expect(result, ['07:00', '12:00', '18:00']);
    });

    test('handles mixed list (int and string)', () {
      final result = converter.fromJson([7, '12:30', 18]);
      expect(result, ['07:00', '12:30', '18:00']);
    });

    test('handles empty list', () {
      final result = converter.fromJson([]);
      expect(result, <String>[]);
    });
  });

  group('ReminderTimesConverter.toJson', () {
    test('passes through string list', () {
      final result = converter.toJson(['07:30', '12:00']);
      expect(result, ['07:30', '12:00']);
    });
  });
}
