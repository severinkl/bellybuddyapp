import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:belly_buddy/services/local_notification_service.dart';

void main() {
  setUpAll(tz.initializeTimeZones);

  group('nextInstanceOfTime', () {
    late tz.Location vienna;
    setUp(() => vienna = tz.getLocation('Europe/Vienna'));

    (int, int, int, int, int) fields(tz.TZDateTime t) =>
        (t.year, t.month, t.day, t.hour, t.minute);

    test('a time still ahead today: today', () {
      final now = tz.TZDateTime(vienna, 2026, 11, 24, 7, 30);

      expect(fields(LocalNotificationService.nextInstanceOfTime(8, 0, now)), (
        2026,
        11,
        24,
        8,
        0,
      ));
    });

    test('a time passed today: tomorrow', () {
      final now = tz.TZDateTime(vienna, 2026, 11, 24, 21);

      expect(fields(LocalNotificationService.nextInstanceOfTime(20, 0, now)), (
        2026,
        11,
        25,
        20,
        0,
      ));
    });

    // The daily reminder repeats at the first instance's time of day, so
    // that instance must keep the wall-clock time across the switch.
    test('passed the evening before the clocks go back: 20:00, not 19:00', () {
      final now = tz.TZDateTime(vienna, 2026, 10, 24, 21);

      expect(fields(LocalNotificationService.nextInstanceOfTime(20, 0, now)), (
        2026,
        10,
        25,
        20,
        0,
      ));
    });

    test('passed the evening before the clocks go forward: 20:00, not '
        '21:00', () {
      final now = tz.TZDateTime(vienna, 2026, 3, 28, 21);

      expect(fields(LocalNotificationService.nextInstanceOfTime(20, 0, now)), (
        2026,
        3,
        29,
        20,
        0,
      ));
    });
  });
}
