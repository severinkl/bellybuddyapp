import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/riverpod_helpers.dart';

/// Switchable signed-in user for the user-switch tests.
class _TestUser extends Notifier<String?> {
  @override
  String? build() => 'u1';

  void set(String? id) => state = id;
}

final _testUserProvider = NotifierProvider<_TestUser, String?>(_TestUser.new);

/// Delays the next [fetch] answer until [release] (opt-in via [gateNext]).
class _GatedBuddyRepository extends FakeBuddyRepository {
  Completer<void>? _gate;
  bool _armed = false;

  void gateNext() {
    _gate = Completer<void>();
    _armed = true;
  }

  void release() => _gate?.complete();

  @override
  Future<BuddyState?> fetch(String userId) async {
    // Read now, answer late: like a slow request returning old data.
    final row = await super.fetch(userId);
    if (_armed) {
      _armed = false;
      await _gate!.future;
    }
    return row;
  }
}

/// November 2026 day [d], local midnight.
DateTime nov(int d) => DateTime(2026, 11, d);

/// Local days `from`..`to` (inclusive) in November 2026.
Set<DateTime> novDays(int from, int to) => {
  for (var d = from; d <= to; d++) nov(d),
};

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _GatedBuddyRepository buddyRepo;
  late FakeEntryRepository entryRepo;
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    buddyRepo = _GatedBuddyRepository();
    entryRepo = FakeEntryRepository();
    now = DateTime(2026, 11, 22, 14);
  });

  ProviderContainer makeContainer({String? userId = 'u1'}) => createContainer(
    overrides: [
      buddyRepositoryProvider.overrideWithValue(buddyRepo),
      entryRepositoryProvider.overrideWithValue(entryRepo),
      currentUserIdProvider.overrideWithValue(userId),
      buddyTodayProvider.overrideWithValue(() => now),
    ],
  );

  Future<BuddyStatus> load(ProviderContainer c) async {
    final status = await c.read(buddyProvider.future);
    return status!;
  }

  group('build', () {
    test('no row: hasRow false, streak computed, nothing saved', () async {
      entryRepo.seedActivityDays(novDays(20, 22));
      final status = await load(makeContainer());

      expect(status.hasRow, isFalse);
      expect(status.streak, 3);
      expect(status.todayCounted, isTrue);
      expect(status.state.savers, 0);
      expect(status.announcements, isEmpty);
      expect(buddyRepo.saveCount, 0);
      expect(buddyRepo.store, isEmpty);
    });

    test('no row and no entries: streak 0', () async {
      final status = await load(makeContainer());

      expect(status.hasRow, isFalse);
      expect(status.streak, 0);
      expect(status.todayCounted, isFalse);
      expect(status.state.name, 'Buddy');
    });

    test('existing row with consumable gap: saved once + saverUsed', () async {
      buddyRepo.store['u1'] = const BuddyState(userId: 'u1', savers: 1);
      entryRepo.seedActivityDays({...novDays(18, 20), nov(22)});

      final status = await load(makeContainer());

      expect(status.hasRow, isTrue);
      expect(status.streak, 5);
      expect(status.announcements, [BuddyAnnouncement.saverUsed]);
      expect(buddyRepo.saveCount, 1);
      expect(buddyRepo.store['u1']!.savedDays, [nov(21)]);
      expect(buddyRepo.store['u1']!.savers, 0);
      expect(status.state.savedDays, [nov(21)]);
    });

    test('existing row without changes is not saved', () async {
      buddyRepo.store['u1'] = const BuddyState(userId: 'u1', savers: 1);
      entryRepo.seedActivityDays(novDays(20, 22));

      final status = await load(makeContainer());

      expect(status.hasRow, isTrue);
      expect(status.streak, 3);
      expect(buddyRepo.saveCount, 0);
      expect(status.announcements, isEmpty);
    });

    test('signed out: null, nothing fetched', () async {
      final c = makeContainer(userId: null);

      expect(await c.read(buddyProvider.future), isNull);
      expect(buddyRepo.fetchCount, 0);
    });

    test('repository throws: AsyncError', () async {
      buddyRepo.throwOnFetch = true;
      final c = makeContainer();
      c.listen(buddyProvider, (_, _) {});

      await expectLater(c.read(buddyProvider.future), throwsA(anything));
      expect(c.read(buddyProvider), isA<AsyncError<BuddyStatus?>>());
    });

    test(
      'streak reaching the window start refetches a larger window',
      () async {
        entryRepo.seedActivityDays({
          for (var i = 0; i < 200; i++) DateTime(2026, 11, 22 - i),
        });

        final status = await load(makeContainer());

        expect(status.streak, 200);
        expect(entryRepo.activityDaysFetchCount, 2);
      },
    );
  });

  group('announcements', () {
    test('second refresh on the same day does not repeat them', () async {
      buddyRepo.store['u1'] = const BuddyState(userId: 'u1', savers: 1);
      entryRepo.seedActivityDays({...novDays(18, 20), nov(22)});
      final c = makeContainer();
      await load(c);

      // Still pending (not yet shown): kept once, not duplicated.
      await c.read(buddyProvider.notifier).refresh();
      expect(c.read(buddyProvider).value!.announcements, [
        BuddyAnnouncement.saverUsed,
      ]);

      c.read(buddyProvider.notifier).clearAnnouncements();
      expect(c.read(buddyProvider).value!.announcements, isEmpty);

      await c.read(buddyProvider.notifier).refresh();
      expect(c.read(buddyProvider).value!.announcements, isEmpty);
      expect(buddyRepo.saveCount, 1);
    });

    test('streakBroken is announced once per break', () async {
      buddyRepo.store['u1'] = const BuddyState(userId: 'u1');
      entryRepo.seedActivityDays(novDays(15, 19));

      final first = await load(makeContainer());
      expect(first.announcements, [BuddyAnnouncement.streakBroken]);

      // App restart, same day.
      final again = await load(makeContainer());
      expect(again.announcements, isEmpty);

      // Next day, the gap is still open: same break, no repeat.
      now = DateTime(2026, 11, 23, 9);
      final nextDay = await load(makeContainer());
      expect(nextDay.announcements, isEmpty);
    });

    test('saverEarned when a milestone adds a saver', () async {
      buddyRepo.store['u1'] = const BuddyState(userId: 'u1');
      entryRepo.seedActivityDays(novDays(16, 22));

      final status = await load(makeContainer());

      expect(status.streak, 7);
      expect(status.announcements, [BuddyAnnouncement.saverEarned]);
      expect(buddyRepo.store['u1']!.savers, 1);
      expect(buddyRepo.store['u1']!.lastMilestone, 7);
    });

    test('no saverEarned when the stock is already full', () async {
      buddyRepo.store['u1'] = const BuddyState(userId: 'u1', savers: 2);
      entryRepo.seedActivityDays(novDays(16, 22));

      final status = await load(makeContainer());

      expect(status.announcements, isEmpty);
      expect(buddyRepo.store['u1']!.lastMilestone, 7);
      expect(buddyRepo.store['u1']!.savers, 2);
    });

    test('goalReached clears the stored goal', () async {
      buddyRepo.store['u1'] = const BuddyState(
        userId: 'u1',
        savers: 2,
        lastMilestone: 7,
        streakGoal: 7,
      );
      entryRepo.seedActivityDays(novDays(14, 22));

      final status = await load(makeContainer());

      expect(status.announcements, [BuddyAnnouncement.goalReached]);
      expect(buddyRepo.store['u1']!.streakGoal, isNull);
      expect(status.state.streakGoal, isNull);
    });
  });

  group('setName', () {
    test('trims and creates the row', () async {
      final c = makeContainer();
      await load(c);

      await c.read(buddyProvider.notifier).setName('  Bauchi  ');

      expect(buddyRepo.store['u1']!.name, 'Bauchi');
      final status = c.read(buddyProvider).value!;
      expect(status.hasRow, isTrue);
      expect(status.state.name, 'Bauchi');
    });

    test('empty or too long names throw ArgumentError', () async {
      final c = makeContainer();
      await load(c);
      final notifier = c.read(buddyProvider.notifier);

      await expectLater(notifier.setName(''), throwsArgumentError);
      await expectLater(notifier.setName('   '), throwsArgumentError);
      await expectLater(notifier.setName('a' * 21), throwsArgumentError);
      expect(buddyRepo.saveCount, 0);
    });

    test('uses the auth repository\'s user while the user id lags', () async {
      // Right after sign-up the reactive user id can still be null while the
      // auth repository already has the new user.
      final c = createContainer(
        overrides: [
          buddyRepositoryProvider.overrideWithValue(buddyRepo),
          entryRepositoryProvider.overrideWithValue(entryRepo),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          currentUserIdProvider.overrideWithValue(null),
          buddyTodayProvider.overrideWithValue(() => now),
        ],
      );

      await c.read(buddyProvider.notifier).setName('Bauchi');

      expect(buddyRepo.store[testUserId]!.name, 'Bauchi');
    });

    test('20 characters are accepted', () async {
      final c = makeContainer();
      await load(c);

      await c.read(buddyProvider.notifier).setName('a' * 20);

      expect(buddyRepo.store['u1']!.name, 'a' * 20);
    });

    test('keeps the rest of an existing row', () async {
      buddyRepo.store['u1'] = const BuddyState(
        userId: 'u1',
        savers: 2,
        streakGoal: 14,
      );
      final c = makeContainer();
      await load(c);

      await c.read(buddyProvider.notifier).setName('Bauchi');

      expect(
        buddyRepo.store['u1'],
        const BuddyState(
          userId: 'u1',
          name: 'Bauchi',
          savers: 2,
          streakGoal: 14,
        ),
      );
    });
  });

  group('setStreakGoal', () {
    test('stores and clears the goal', () async {
      buddyRepo.store['u1'] = const BuddyState(userId: 'u1');
      final c = makeContainer();
      await load(c);

      await c.read(buddyProvider.notifier).setStreakGoal(14);
      expect(buddyRepo.store['u1']!.streakGoal, 14);
      expect(c.read(buddyProvider).value!.state.streakGoal, 14);

      await c.read(buddyProvider.notifier).setStreakGoal(null);
      expect(buddyRepo.store['u1']!.streakGoal, isNull);
    });
  });

  group('completeOnboarding', () {
    test('twice: savers +1 and timestamp only once', () async {
      final c = makeContainer();
      await load(c);
      final notifier = c.read(buddyProvider.notifier);

      await notifier.completeOnboarding();
      final completedAt = buddyRepo.store['u1']!.onboardingCompletedAt;
      expect(completedAt, now);
      expect(buddyRepo.store['u1']!.savers, 1);

      now = DateTime(2026, 11, 22, 15);
      await notifier.completeOnboarding();
      expect(buddyRepo.store['u1']!.savers, 1);
      expect(buddyRepo.store['u1']!.onboardingCompletedAt, completedAt);

      final status = c.read(buddyProvider).value!;
      expect(status.hasRow, isTrue);
      expect(status.state.onboardingCompletedAt, completedAt);
    });

    test('new row starts at the current milestone (no saver flood)', () async {
      entryRepo.seedActivityDays(novDays(1, 22));
      final c = makeContainer();
      await load(c);

      await c.read(buddyProvider.notifier).completeOnboarding();

      final stored = buddyRepo.store['u1']!;
      expect(stored.lastMilestone, 21);
      expect(stored.savers, 1);
      expect(c.read(buddyProvider).value!.announcements, isEmpty);
    });

    test('gift saver is capped at 2', () async {
      buddyRepo.store['u1'] = const BuddyState(userId: 'u1', savers: 2);
      final c = makeContainer();
      await load(c);

      await c.read(buddyProvider.notifier).completeOnboarding();

      expect(buddyRepo.store['u1']!.savers, 2);
      expect(buddyRepo.store['u1']!.onboardingCompletedAt, now);
    });

    test('grantGiftSaver: false grants no saver', () async {
      final c = makeContainer();
      await load(c);

      await c
          .read(buddyProvider.notifier)
          .completeOnboarding(grantGiftSaver: false);

      expect(buddyRepo.store['u1']!.savers, 0);
      expect(buddyRepo.store['u1']!.onboardingCompletedAt, now);
    });

    test('a slow refresh cannot overwrite a later mutation', () async {
      final c = makeContainer();
      await load(c);
      final notifier = c.read(buddyProvider.notifier);

      buddyRepo.gateNext();
      final refresh = notifier.refresh();
      final complete = notifier.completeOnboarding();
      await settle();
      buddyRepo.release();
      await Future.wait([refresh, complete]);

      final status = c.read(buddyProvider).value!;
      expect(status.hasRow, isTrue);
      expect(status.state.onboardingCompletedAt, now);
      expect(buddyRepo.store['u1']!.savers, 1);
    });
  });

  group('refresh', () {
    test('picks up new activity', () async {
      buddyRepo.store['u1'] = const BuddyState(userId: 'u1');
      entryRepo.seedActivityDays(novDays(20, 21));
      final c = makeContainer();
      expect((await load(c)).todayCounted, isFalse);

      entryRepo.seedActivityDays(novDays(20, 22));
      await c.read(buddyProvider.notifier).refresh();

      final status = c.read(buddyProvider).value!;
      expect(status.todayCounted, isTrue);
      expect(status.streak, 3);
    });

    test('failure keeps the last data and rethrows', () async {
      final c = makeContainer();
      await load(c);

      buddyRepo.throwOnFetch = true;
      await expectLater(
        c.read(buddyProvider.notifier).refresh(),
        throwsA(anything),
      );
      expect(c.read(buddyProvider).value, isNotNull);
    });
  });

  group('user switch', () {
    ProviderContainer makeSwitchable() => createContainer(
      overrides: [
        buddyRepositoryProvider.overrideWithValue(buddyRepo),
        entryRepositoryProvider.overrideWithValue(entryRepo),
        currentUserIdProvider.overrideWith(
          (ref) => ref.watch(_testUserProvider),
        ),
        buddyTodayProvider.overrideWithValue(() => now),
      ],
    );

    test('u1 -> u2 rebuilds from u2, sign-out -> null', () async {
      buddyRepo.store['u1'] = const BuddyState(userId: 'u1', name: 'Eins');
      buddyRepo.store['u2'] = const BuddyState(userId: 'u2', name: 'Zwei');
      final c = makeSwitchable();
      c.listen(buddyProvider, (_, _) {});

      expect((await load(c)).state.name, 'Eins');

      c.read(_testUserProvider.notifier).set('u2');
      final u2 = await load(c);
      expect(u2.state.name, 'Zwei');
      expect(u2.state.userId, 'u2');

      c.read(_testUserProvider.notifier).set(null);
      expect(await c.read(buddyProvider.future), isNull);
    });

    test('pending announcements do not leak to the next user', () async {
      buddyRepo.store['u1'] = const BuddyState(userId: 'u1', savers: 1);
      entryRepo.seedActivityDays({...novDays(18, 20), nov(22)});
      final c = makeSwitchable();
      c.listen(buddyProvider, (_, _) {});
      expect((await load(c)).announcements, [BuddyAnnouncement.saverUsed]);

      c.read(_testUserProvider.notifier).set('u2');
      await load(c);
      await c.read(buddyProvider.notifier).refresh();

      expect(c.read(buddyProvider).value!.announcements, isEmpty);
    });
  });
}
