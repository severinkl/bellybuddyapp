import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/daily_review_provider.dart';
import 'package:belly_buddy/providers/daily_review_reminder_provider.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/providers/today_provider.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
import 'package:belly_buddy/utils/wall_clock.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';

final _today = DateTime(2026, 11, 27);

DateTime _at(int h, [int m = 0]) =>
    DateTime(_today.year, _today.month, _today.day, h, m);

/// `tracked_at` as production reads it: the wall clock sent in the UTC slot.
MealEntry _meal(String id, {DateTime? day}) {
  final d = day ?? _today;
  return testMealEntry(
    id: id,
    trackedAt: wallClockFromWire(
      DateTime.utc(d.year, d.month, d.day, 12).toIso8601String(),
    ),
  );
}

class _Profile extends ProfileNotifier {
  _Profile(this._initial);
  final UserProfile _initial;

  @override
  AsyncValue<UserProfile?> build() => AsyncValue.data(_initial);

  void set(UserProfile p) => state = AsyncValue.data(p);
}

class _Entries extends EntriesNotifier {
  _Entries(this._initial);
  final EntriesState _initial;

  @override
  EntriesState build() => _initial;

  void set(EntriesState s) => state = s;
}

class _Today extends TodayNotifier {
  _Today(this._initial);
  final DateTime _initial;

  @override
  DateTime build() => _initial;

  void set(DateTime day) => state = day;
}

class _Closed extends DailyReviewClosedNotifier {
  _Closed(this._initial);
  final DateTime? _initial;

  @override
  Future<DateTime?> build() async => _initial;

  void set(DateTime? day) => state = AsyncData(day);
}

void main() {
  group('dailyReviewNoticeDue', () {
    const review = 19 * 60 + 30;

    bool due({
      bool on = true,
      int meals = 1,
      DateTime? now,
      DateTime? closed,
    }) => dailyReviewNoticeDue(
      reminderOn: on,
      todayMeals: meals,
      now: now ?? _at(18),
      reviewMinutes: review,
      closedDay: closed,
    );

    test('due: on, 1 meal, 18:00, review 19:30, not closed → true; '
        'off / 0 meals / 19:30 / closed → false', () {
      expect(due(), isTrue);
      expect(due(on: false), isFalse);
      expect(due(meals: 0), isFalse);
      expect(due(now: _at(19, 30)), isFalse);
      expect(due(now: _at(22)), isFalse);
      expect(due(closed: _today), isFalse);
      // Yesterday's review closed: today's notice still comes.
      expect(due(closed: DateTime(2026, 11, 26)), isTrue);
    });
  });

  group('dailyReviewReminderSyncProvider', () {
    late MockNotificationRepository notifications;
    late DateTime now;
    late SwitchableUserId user;

    /// The notice calls in order; a schedule logs its start and its end.
    late List<String> log;

    /// While set, a schedule completes only once it completes (a slow
    /// plugin).
    Completer<void>? gate;

    setUp(() {
      notifications = MockNotificationRepository();
      now = _at(12);
      user = SwitchableUserId();
      log = [];
      gate = null;
      when(
        () => notifications.scheduleDailyReview(
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          buddyName: any(named: 'buddyName'),
        ),
      ).thenAnswer((i) async {
        final at = '${i.namedArguments[#hour]}:${i.namedArguments[#minute]}'
            .toString();
        log.add('schedule $at');
        await gate?.future;
        log.add('scheduled $at');
      });
      when(() => notifications.cancelDailyReview()).thenAnswer((_) async {
        log.add('cancel');
      });
    });

    ProviderContainer container({
      UserProfile? profile,
      List<MealEntry> meals = const [],
      DateTime? closed,
      String? buddyName,
    }) {
      final c = createContainer(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(notifications),
          user.override,
          buddyClockProvider.overrideWithValue(() => now),
          todayProvider.overrideWith(() => _Today(_today)),
          profileProvider.overrideWith(
            () =>
                _Profile(profile ?? testUserProfile(dailyReviewReminder: true)),
          ),
          entriesProvider.overrideWith(
            () => _Entries(EntriesState(meals: meals, day: _today)),
          ),
          dailyReviewClosedProvider.overrideWith(() => _Closed(closed)),
          buddyProvider.overrideWith(
            () => FakeBuddyNotifier(
              () => buddyName == null ? null : buddyStatus(name: buddyName),
            ),
          ),
        ],
      );
      c.listen(dailyReviewReminderSyncProvider, (_, _) {});
      return c;
    }

    Future<void> settle(ProviderContainer c) async {
      await c.read(buddyProvider.future);
      await c.read(dailyReviewClosedProvider.future);
      await Future<void>.delayed(Duration.zero);
      await c.read(dailyReviewNoticeQueueProvider).idle;
    }

    void verifyScheduled(int hour, int minute, {String? buddyName}) => verify(
      () => notifications.scheduleDailyReview(
        hour: hour,
        minute: minute,
        buddyName: buddyName,
      ),
    ).called(1);

    test('sync: first meal of the day saved at 12:00 with the reminder on → '
        'scheduleDailyReview(19, 30) once', () async {
      final c = container();
      await settle(c);
      verifyNever(
        () => notifications.scheduleDailyReview(
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          buddyName: any(named: 'buddyName'),
        ),
      );

      final entries = c.read(entriesProvider.notifier) as _Entries;
      entries.set(EntriesState(meals: [_meal('m1')], day: _today));
      await Future<void>.delayed(Duration.zero);
      // A reload of the same day changes nothing.
      entries.set(
        EntriesState(meals: [_meal('m1')], day: _today, isLoading: true),
      );
      entries.set(EntriesState(meals: [_meal('m1')], day: _today));
      await Future<void>.delayed(Duration.zero);

      verifyScheduled(19, 30);
    });

    test('sync: a meal of yesterday does not count', () async {
      final c = container(meals: [_meal('old', day: DateTime(2026, 11, 26))]);
      await settle(c);

      verifyNever(
        () => notifications.scheduleDailyReview(
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          buddyName: any(named: 'buddyName'),
        ),
      );
      verify(() => notifications.cancelDailyReview()).called(1);
    });

    test('sync: the Buddy\'s name goes along', () async {
      final c = container(meals: [_meal('m1')], buddyName: 'Bello');
      await settle(c);

      verifyScheduled(19, 30, buddyName: 'Bello');
    });

    test('sync: switch off → cancelDailyReview; time changed to 21:00 → '
        'scheduled at 21:00', () async {
      final on = testUserProfile(dailyReviewReminder: true);
      final c = container(profile: on, meals: [_meal('m1')]);
      await settle(c);
      verifyScheduled(19, 30);

      final profile = c.read(profileProvider.notifier) as _Profile;
      profile.set(on.copyWith(dailyReviewReminder: false));
      await Future<void>.delayed(Duration.zero);
      verify(() => notifications.cancelDailyReview()).called(1);

      profile.set(on.copyWith(dailyReviewTime: '21:00'));
      await Future<void>.delayed(Duration.zero);
      verifyScheduled(21, 0);
    });

    test('sync: card closed before the time → cancelled', () async {
      final c = container(meals: [_meal('m1')]);
      await settle(c);
      verifyScheduled(19, 30);

      now = _at(17);
      (c.read(dailyReviewClosedProvider.notifier) as _Closed).set(_today);
      await Future<void>.delayed(Duration.zero);

      verify(() => notifications.cancelDailyReview()).called(1);
    });

    test('sync: a late schedule, then switched off → the cancel runs after '
        'it, so nothing stays pending', () async {
      gate = Completer<void>();
      final on = testUserProfile(dailyReviewReminder: true);
      final c = container(profile: on, meals: [_meal('m1')]);
      await c.read(buddyProvider.future);
      await c.read(dailyReviewClosedProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(log, ['schedule 19:30']);

      (c.read(profileProvider.notifier) as _Profile).set(
        on.copyWith(dailyReviewReminder: false),
      );
      await Future<void>.delayed(Duration.zero);
      expect(log, ['schedule 19:30'], reason: 'waits for the schedule');

      gate!.complete();
      await c.read(dailyReviewNoticeQueueProvider).idle;
      expect(log, ['schedule 19:30', 'scheduled 19:30', 'cancel']);
    });

    test('sync: changes while a schedule is in flight: only the last state '
        'runs after it', () async {
      gate = Completer<void>();
      final on = testUserProfile(dailyReviewReminder: true);
      final c = container(profile: on, meals: [_meal('m1')]);
      await c.read(buddyProvider.future);
      await c.read(dailyReviewClosedProvider.future);
      await Future<void>.delayed(Duration.zero);

      final profile = c.read(profileProvider.notifier) as _Profile;
      profile.set(on.copyWith(dailyReviewReminder: false));
      await Future<void>.delayed(Duration.zero);
      profile.set(on.copyWith(dailyReviewTime: '21:00'));
      await Future<void>.delayed(Duration.zero);

      gate!.complete();
      await c.read(dailyReviewNoticeQueueProvider).idle;
      expect(log, [
        'schedule 19:30',
        'scheduled 19:30',
        'schedule 21:0',
        'scheduled 21:0',
      ]);
    });

    test('sync: signed out while a schedule is in flight → cancelled after '
        'it', () async {
      gate = Completer<void>();
      final c = container(meals: [_meal('m1')], buddyName: 'Bello');
      await c.read(buddyProvider.future);
      await c.read(dailyReviewClosedProvider.future);
      await Future<void>.delayed(Duration.zero);

      user.set(c, null);
      await Future<void>.delayed(Duration.zero);
      expect(log, ['schedule 19:30']);

      gate!.complete();
      await c.read(dailyReviewNoticeQueueProvider).idle;
      expect(log, ['schedule 19:30', 'scheduled 19:30', 'cancel']);
    });

    test('sync: time moved after the old time passed (20:00, 19:30 → 21:00) '
        '→ scheduled at 21:00', () async {
      now = _at(20);
      final on = testUserProfile(dailyReviewReminder: true);
      final c = container(profile: on, meals: [_meal('m1')]);
      await settle(c);
      // Past 19:30: nothing pending.
      expect(log, ['cancel']);

      (c.read(profileProvider.notifier) as _Profile).set(
        on.copyWith(dailyReviewTime: '21:00'),
      );
      await settle(c);
      expect(log, ['cancel', 'schedule 21:0', 'scheduled 21:0']);
    });

    test(
      'sync: a new day: nothing while the entries hold the old one; the '
      'new day without a meal → cancelled; its first meal → scheduled',
      () async {
        final c = container(meals: [_meal('m1')]);
        await settle(c);
        expect(log, ['schedule 19:30', 'scheduled 19:30']);
        log.clear();

        final tomorrow = DateTime(2026, 11, 28);
        now = DateTime(2026, 11, 28, 8);
        (c.read(todayProvider.notifier) as _Today).set(tomorrow);
        await settle(c);
        expect(log, isEmpty);

        final entries = c.read(entriesProvider.notifier) as _Entries;
        entries.set(EntriesState(meals: const [], day: tomorrow));
        await settle(c);
        expect(log, ['cancel']);

        entries.set(
          EntriesState(
            meals: [_meal('m2', day: tomorrow)],
            day: tomorrow,
          ),
        );
        await settle(c);
        expect(log, ['cancel', 'schedule 19:30', 'scheduled 19:30']);
      },
    );

    test('sync: the last meal of today deleted → cancelled', () async {
      final c = container(meals: [_meal('m1'), _meal('m2')]);
      await settle(c);
      log.clear();

      final entries = c.read(entriesProvider.notifier) as _Entries;
      entries.set(EntriesState(meals: [_meal('m2')], day: _today));
      await settle(c);
      expect(log, [
        'schedule 19:30',
        'scheduled 19:30',
      ], reason: 'one meal left: still due');
      log.clear();

      entries.set(EntriesState(meals: const [], day: _today));
      await settle(c);
      expect(log, ['cancel']);
    });

    test('sync: errors are logged, not thrown', () async {
      when(
        () => notifications.scheduleDailyReview(
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          buddyName: any(named: 'buddyName'),
        ),
      ).thenAnswer((_) async => throw StateError('plugin'));
      final c = container(meals: [_meal('m1')]);
      await settle(c);

      verifyScheduled(19, 30);
    });
  });
}
