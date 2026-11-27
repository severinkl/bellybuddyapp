import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/daily_review_provider.dart';
import 'package:belly_buddy/providers/daily_review_reminder_provider.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
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

/// Wall clock in the UTC slot, as `tracked_at` is read.
MealEntry _meal(String id, {DateTime? day}) {
  final d = day ?? _today;
  return testMealEntry(
    id: id,
    trackedAt: DateTime.utc(d.year, d.month, d.day, 12),
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

    setUp(() {
      notifications = MockNotificationRepository();
      now = _at(12);
      when(
        () => notifications.scheduleDailyReview(
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          buddyName: any(named: 'buddyName'),
        ),
      ).thenAnswer((_) async {});
      when(() => notifications.cancelDailyReview()).thenAnswer((_) async {});
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
          buddyClockProvider.overrideWithValue(() => now),
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
