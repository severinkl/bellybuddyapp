import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:belly_buddy/models/tolerance_test.dart';
import 'package:belly_buddy/services/insights/test_copy.dart';
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

  group('todayAt (the daily review\'s one-shot)', () {
    late tz.Location vienna;
    setUp(() => vienna = tz.getLocation('Europe/Vienna'));

    test('still ahead today: today at that time', () {
      final now = tz.TZDateTime(vienna, 2026, 11, 27, 12);
      final at = LocalNotificationService.todayAt(19, 30, now)!;

      expect(
        (at.year, at.month, at.day, at.hour, at.minute),
        (2026, 11, 27, 19, 30),
      );
      expect(at.location, vienna);
    });

    test('passed (or now): null, never tomorrow', () {
      expect(
        LocalNotificationService.todayAt(
          19,
          30,
          tz.TZDateTime(vienna, 2026, 11, 27, 19, 30),
        ),
        isNull,
      );
      expect(
        LocalNotificationService.todayAt(
          19,
          30,
          tz.TZDateTime(vienna, 2026, 11, 27, 22),
        ),
        isNull,
      );
    });
  });

  group('the test reminders', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    late List<MethodCall> calls;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      calls = [];
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    List<Map<Object?, Object?>> scheduled() => [
      for (final c in calls)
        if (c.method == 'zonedSchedule') c.arguments as Map<Object?, Object?>,
    ];

    test('test reminders: ids 3001 and 3002 at 09:00 local on the reintro '
        'and result days', () async {
      await LocalNotificationService.scheduleTestReminders(
        reintroBody: TestCopy.reintroNotification(
          const TestSubject('ingredient', 'zwiebel', 'Zwiebel'),
        ),
        reintroDay: DateTime(2099, 3, 6),
        resultDay: DateTime(2099, 3, 9),
        timezone: 'Europe/Vienna',
      );

      final s = scheduled();
      expect([for (final n in s) n['id']], [3001, 3002]);
      expect(
        [for (final n in s) n['scheduledDateTime']],
        ['2099-03-06T09:00:00', '2099-03-09T09:00:00'],
      );
      expect({for (final n in s) n['timeZoneName']}, {'Europe/Vienna'});
      expect({for (final n in s) n['payload']}, {'/patterns/test'});
      expect(
        s[0]['body'],
        'Ab heute darf Zwiebel wieder auf den Teller – ich schau, wie\'s '
        'deinem Bauch damit geht.',
      );
      expect(
        s[1]['body'],
        'Dein Verträglichkeits-Test ist fertig. Magst du reinschauen?',
      );
      // Pending ones replaced first.
      expect(calls.first.method, 'cancel');
    });

    test('a day already passed schedules none', () async {
      await LocalNotificationService.scheduleTestReminders(
        reintroBody: TestCopy.reintroNotification(
          const TestSubject('ingredient', 'zwiebel', 'Zwiebel'),
        ),
        reintroDay: DateTime(2020, 3, 6),
        resultDay: DateTime(2099, 3, 9),
        timezone: 'Europe/Vienna',
      );

      expect([for (final n in scheduled()) n['id']], [3002]);
    });

    test('cancelTestReminders cancels both ids', () async {
      await LocalNotificationService.cancelTestReminders();

      expect(
        [
          for (final c in calls)
            if (c.method == 'cancel') (c.arguments as Map)['id'],
        ],
        [3001, 3002],
      );
    });

    test('testReminderAt: 09:00 on the wall-clock date; null once passed', () {
      final vienna = tz.getLocation('Europe/Vienna');
      final now = tz.TZDateTime(vienna, 2026, 12, 6, 8, 59);
      final at = LocalNotificationService.testReminderAt(
        DateTime(2026, 12, 6),
        now,
      )!;
      expect((at.year, at.month, at.day, at.hour), (2026, 12, 6, 9));
      expect(
        LocalNotificationService.testReminderAt(
          DateTime(2026, 12, 6),
          tz.TZDateTime(vienna, 2026, 12, 6, 9),
        ),
        isNull,
      );
    });
  });
}
