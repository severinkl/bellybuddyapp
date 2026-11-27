import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/models/progress.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/providers/progress_provider.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/services/progress/progress_engine.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/riverpod_helpers.dart';

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// The signed-in user's id, switchable.
final _user = SwitchableUserId('u1');

/// A source with [gutFeelings] gut-feeling entries on [now]'s day and
/// [klo] Klo entries the day before.
ProgressSource _source(DateTime now, {int gutFeelings = 1, int klo = 0}) =>
    ProgressSource(
      gutFeelings: [
        for (var i = 0; i < gutFeelings; i++)
          testGutFeelingEntry(trackedAt: now.subtract(Duration(minutes: i))),
      ],
      toilets: [
        for (var i = 0; i < klo; i++)
          (
            trackedAt: now.subtract(Duration(days: 1, minutes: i)),
            stoolType: 3,
          ),
      ],
      otherTimes: const [],
    );

void main() {
  // The foreground signal's AppLifecycleListener needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 11, 26, 14);
  late FakeEntryRepository entryRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    entryRepo = FakeEntryRepository()..progressSource = _source(now);
  });

  ProviderContainer makeContainer({List<Override> overrides = const []}) =>
      ProviderContainer.test(
        overrides: [
          entryRepositoryProvider.overrideWithValue(entryRepo),
          buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
          _user.override,
          buddyClockProvider.overrideWithValue(() => now),
          ...overrides,
        ],
      );

  ProgressNotifier notifier(ProviderContainer c) =>
      c.read(progressProvider.notifier);

  test('signed out → null, no fetch', () async {
    final c = makeContainer();
    _user.set(c, null);

    expect(await c.read(progressProvider.future), isNull);
    expect(entryRepo.progressSourceRequests, isEmpty);
  });

  test('computes from the fetched source with the buddy saved days', () async {
    final saved = [DateTime(2026, 11, 24)];
    final source = _source(now, klo: 2);
    entryRepo.progressSource = source;
    final c = makeContainer(
      overrides: [
        buddyProvider.overrideWith(
          () => FakeBuddyNotifier(
            () => BuddyStatus(
              state: BuddyState(userId: 'u1', savedDays: saved),
              hasRow: true,
              streak: 0,
              todayCounted: false,
            ),
          ),
        ),
      ],
    );

    final progress = await c.read(progressProvider.future);

    // Klo on the 25th, gut feeling on the 26th, saved the 24th: 3 in a row.
    expect(
      progress,
      computeProgress(source, now: now, savedDays: saved.toSet()),
    );
    expect(progress!.longestStreak, 3);
    expect(entryRepo.progressSourceRequests, [(userId: 'u1', now: now)]);
  });

  test('without a Buddy, or when it fails, no saved days', () async {
    final source = _source(now, klo: 1);
    entryRepo.progressSource = source;
    final failing = makeContainer(
      overrides: [
        buddyProvider.overrideWith(
          () => FakeBuddyNotifier(() => throw Exception('offline')),
        ),
      ],
    );
    final none = makeContainer(
      overrides: [buddyProvider.overrideWith(() => FakeBuddyNotifier())],
    );

    for (final c in [failing, none]) {
      final progress = await c.read(progressProvider.future);
      expect(progress, computeProgress(source, now: now));
      expect(progress!.longestStreak, 2);
    }
  });

  test('an entry write recomputes', () async {
    final c = makeContainer();
    c.listen(progressProvider, (_, _) {});
    await c.read(progressProvider.future);
    final next = _source(now, gutFeelings: 3);
    entryRepo.progressSource = next;

    await c.read(entriesProvider.notifier).addGutFeeling(testGutFeelingEntry());
    await settle();

    expect(entryRepo.progressSourceRequests, hasLength(2));
    expect(c.read(progressProvider).value, computeProgress(next, now: now));
  });

  test('user change reloads', () async {
    final a = _source(now, gutFeelings: 3);
    final b = _source(now, gutFeelings: 1, klo: 1);
    entryRepo.progressSource = a;
    final c = makeContainer();
    final heard = <AsyncValue<Progress?>>[];
    c.listen(progressProvider, (_, next) => heard.add(next));
    await c.read(progressProvider.future);
    entryRepo.holdProgressSource = true;

    _user.set(c, 'u2');
    await settle();

    expect(entryRepo.progressSourceRequests.last.userId, 'u2');
    final reloading = c.read(progressProvider);
    expect(reloading.isReloading, isTrue);
    expect(reloading, isNot(isA<AsyncData<Progress?>>()));

    entryRepo.heldProgressSources.single.complete(b);
    await settle();

    expect(c.read(progressProvider).value, computeProgress(b, now: now));
    // A's progress was never data after the switch.
    final afterSwitch = heard.skipWhile((v) => v is AsyncData).toList();
    expect(afterSwitch.whereType<AsyncData<Progress?>>().map((v) => v.value), [
      computeProgress(b, now: now),
    ]);
  });

  test('a failing fetch is an error; refresh after it succeeds', () async {
    entryRepo.progressSourceError = Exception('offline');
    final c = makeContainer();
    c.listen(progressProvider, (_, _) {});
    await settle();
    expect(c.read(progressProvider).hasError, isTrue);
    expect(c.read(progressProvider).hasValue, isFalse);

    entryRepo.progressSourceError = null;
    await notifier(c).refresh();

    expect(c.read(progressProvider), isA<AsyncData<Progress?>>());
    expect(
      c.read(progressProvider).value,
      computeProgress(_source(now), now: now),
    );
  });
}
