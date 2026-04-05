import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz_lib;

import 'package:belly_buddy/repositories/notification_repository.dart';

import '../helpers/mocks.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockNotificationScheduler scheduler;
  late NotificationRepository repo;

  setUpAll(() {
    registerFallbackValue(<String>[]);
    tz.initializeTimeZones();
    tz_lib.setLocalLocation(tz_lib.getLocation('Europe/Berlin'));
  });

  setUp(() {
    scheduler = MockNotificationScheduler();
    repo = NotificationRepository(scheduler);

    when(
      () => scheduler.scheduleMealReminders(
        mealReminderTimes: any(named: 'mealReminderTimes'),
        timezone: any(named: 'timezone'),
      ),
    ).thenAnswer((_) async {});
    when(() => scheduler.cancelMealReminders()).thenAnswer((_) async {});
    when(
      () => scheduler.scheduleMoodReminders(
        moodReminderTimes: any(named: 'moodReminderTimes'),
        timezone: any(named: 'timezone'),
      ),
    ).thenAnswer((_) async {});
    when(() => scheduler.cancelMoodReminders()).thenAnswer((_) async {});
    when(() => scheduler.cancelAll()).thenAnswer((_) async {});
  });

  group('syncNotifications', () {
    test(
      'schedules meal reminders when enabled and times are not empty',
      () async {
        final profile = testUserProfile(
          remindersEnabled: true,
          mealReminderTimes: ['08:00', '12:00'],
          dailySummaryEnabled: false,
          timezone: 'Europe/Berlin',
        );

        await repo.syncNotifications(profile);

        verify(
          () => scheduler.scheduleMealReminders(
            mealReminderTimes: ['08:00', '12:00'],
            timezone: 'Europe/Berlin',
          ),
        ).called(1);
        verifyNever(() => scheduler.cancelMealReminders());
      },
    );

    test('cancels meal reminders when disabled', () async {
      final profile = testUserProfile(
        remindersEnabled: false,
        mealReminderTimes: ['08:00'],
        dailySummaryEnabled: false,
      );

      await repo.syncNotifications(profile);

      verify(() => scheduler.cancelMealReminders()).called(1);
      verifyNever(
        () => scheduler.scheduleMealReminders(
          mealReminderTimes: any(named: 'mealReminderTimes'),
          timezone: any(named: 'timezone'),
        ),
      );
    });

    test('cancels meal reminders when times are empty', () async {
      final profile = testUserProfile(
        remindersEnabled: true,
        mealReminderTimes: [],
        dailySummaryEnabled: false,
      );

      await repo.syncNotifications(profile);

      verify(() => scheduler.cancelMealReminders()).called(1);
      verifyNever(
        () => scheduler.scheduleMealReminders(
          mealReminderTimes: any(named: 'mealReminderTimes'),
          timezone: any(named: 'timezone'),
        ),
      );
    });

    test('schedules mood reminders when enabled', () async {
      final profile = testUserProfile(
        remindersEnabled: false,
        mealReminderTimes: [],
        dailySummaryEnabled: true,
        moodReminderTimes: ['20:00'],
        timezone: 'Europe/Berlin',
      );

      await repo.syncNotifications(profile);

      verify(
        () => scheduler.scheduleMoodReminders(
          moodReminderTimes: ['20:00'],
          timezone: 'Europe/Berlin',
        ),
      ).called(1);
      verifyNever(() => scheduler.cancelMoodReminders());
    });

    test('cancels mood reminders when disabled', () async {
      final profile = testUserProfile(
        remindersEnabled: false,
        mealReminderTimes: [],
        dailySummaryEnabled: false,
      );

      await repo.syncNotifications(profile);

      verify(() => scheduler.cancelMoodReminders()).called(1);
      verifyNever(
        () => scheduler.scheduleMoodReminders(
          moodReminderTimes: any(named: 'moodReminderTimes'),
          timezone: any(named: 'timezone'),
        ),
      );
    });

    test('uses device timezone (ignores profile timezone)', () async {
      final profile = testUserProfile(
        remindersEnabled: true,
        mealReminderTimes: ['09:00'],
        dailySummaryEnabled: true,
        moodReminderTimes: ['20:00'],
        timezone: null,
      );

      await repo.syncNotifications(profile);

      verify(
        () => scheduler.scheduleMealReminders(
          mealReminderTimes: any(named: 'mealReminderTimes'),
          timezone: 'Europe/Berlin',
        ),
      ).called(1);
      verify(
        () => scheduler.scheduleMoodReminders(
          moodReminderTimes: any(named: 'moodReminderTimes'),
          timezone: 'Europe/Berlin',
        ),
      ).called(1);
    });
  });

  group('cancelAll', () {
    test('delegates to scheduler.cancelAll', () async {
      await repo.cancelAll();

      verify(() => scheduler.cancelAll()).called(1);
    });
  });

  group('push notification delegation', () {
    test('onForegroundMessage returns a Stream<RemoteMessage>', () {
      expect(repo.onForegroundMessage, isA<Stream<RemoteMessage>>());
    });

    test('onMessageOpenedApp returns a Stream<RemoteMessage>', () {
      expect(repo.onMessageOpenedApp, isA<Stream<RemoteMessage>>());
    });

    test('extractRoute returns null when data has no route key', () {
      const message = RemoteMessage(data: {});
      expect(repo.extractRoute(message), isNull);
    });

    test('extractRoute returns route string from message data', () {
      const message = RemoteMessage(data: {'route': '/diary'});
      expect(repo.extractRoute(message), '/diary');
    });
  });
}
