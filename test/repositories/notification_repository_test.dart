import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/repositories/notification_repository.dart';

import '../helpers/mocks.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockNotificationScheduler scheduler;
  late NotificationRepository repo;

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    scheduler = MockNotificationScheduler();
    repo = NotificationRepository(scheduler);

    when(
      () => scheduler.scheduleReminders(
        reminderTimes: any(named: 'reminderTimes'),
        timezone: any(named: 'timezone'),
      ),
    ).thenAnswer((_) async {});
    when(() => scheduler.cancelReminders()).thenAnswer((_) async {});
    when(
      () => scheduler.scheduleDailySummary(
        dailySummaryTime: any(named: 'dailySummaryTime'),
        timezone: any(named: 'timezone'),
      ),
    ).thenAnswer((_) async {});
    when(() => scheduler.cancelDailySummary()).thenAnswer((_) async {});
    when(() => scheduler.cancelAll()).thenAnswer((_) async {});
  });

  group('syncNotifications', () {
    test('schedules reminders when enabled and times are not empty', () async {
      final profile = testUserProfile(
        remindersEnabled: true,
        reminderTimes: ['08:00', '12:00'],
        dailySummaryEnabled: false,
        timezone: 'Europe/Berlin',
      );

      await repo.syncNotifications(profile);

      verify(
        () => scheduler.scheduleReminders(
          reminderTimes: ['08:00', '12:00'],
          timezone: 'Europe/Berlin',
        ),
      ).called(1);
      verifyNever(() => scheduler.cancelReminders());
    });

    test('cancels reminders when disabled', () async {
      final profile = testUserProfile(
        remindersEnabled: false,
        reminderTimes: ['08:00'],
        dailySummaryEnabled: false,
      );

      await repo.syncNotifications(profile);

      verify(() => scheduler.cancelReminders()).called(1);
      verifyNever(
        () => scheduler.scheduleReminders(
          reminderTimes: any(named: 'reminderTimes'),
          timezone: any(named: 'timezone'),
        ),
      );
    });

    test('cancels reminders when times are empty', () async {
      final profile = testUserProfile(
        remindersEnabled: true,
        reminderTimes: [],
        dailySummaryEnabled: false,
      );

      await repo.syncNotifications(profile);

      verify(() => scheduler.cancelReminders()).called(1);
      verifyNever(
        () => scheduler.scheduleReminders(
          reminderTimes: any(named: 'reminderTimes'),
          timezone: any(named: 'timezone'),
        ),
      );
    });

    test('schedules daily summary when enabled', () async {
      final profile = testUserProfile(
        remindersEnabled: false,
        reminderTimes: [],
        dailySummaryEnabled: true,
        dailySummaryTime: '20:00',
        timezone: 'Europe/Berlin',
      );

      await repo.syncNotifications(profile);

      verify(
        () => scheduler.scheduleDailySummary(
          dailySummaryTime: '20:00',
          timezone: 'Europe/Berlin',
        ),
      ).called(1);
      verifyNever(() => scheduler.cancelDailySummary());
    });

    test('cancels daily summary when disabled', () async {
      final profile = testUserProfile(
        remindersEnabled: false,
        reminderTimes: [],
        dailySummaryEnabled: false,
      );

      await repo.syncNotifications(profile);

      verify(() => scheduler.cancelDailySummary()).called(1);
      verifyNever(
        () => scheduler.scheduleDailySummary(
          dailySummaryTime: any(named: 'dailySummaryTime'),
          timezone: any(named: 'timezone'),
        ),
      );
    });

    test('uses profile timezone when set', () async {
      final profile = testUserProfile(
        remindersEnabled: true,
        reminderTimes: ['09:00'],
        dailySummaryEnabled: true,
        dailySummaryTime: '21:00',
        timezone: 'America/New_York',
      );

      await repo.syncNotifications(profile);

      verify(
        () => scheduler.scheduleReminders(
          reminderTimes: any(named: 'reminderTimes'),
          timezone: 'America/New_York',
        ),
      ).called(1);
      verify(
        () => scheduler.scheduleDailySummary(
          dailySummaryTime: any(named: 'dailySummaryTime'),
          timezone: 'America/New_York',
        ),
      ).called(1);
    });

    test('defaults to Europe/Berlin when timezone is null', () async {
      final profile = testUserProfile(
        remindersEnabled: true,
        reminderTimes: ['09:00'],
        dailySummaryEnabled: true,
        dailySummaryTime: '20:00',
        timezone: null,
      );

      await repo.syncNotifications(profile);

      verify(
        () => scheduler.scheduleReminders(
          reminderTimes: any(named: 'reminderTimes'),
          timezone: 'Europe/Berlin',
        ),
      ).called(1);
      verify(
        () => scheduler.scheduleDailySummary(
          dailySummaryTime: any(named: 'dailySummaryTime'),
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
