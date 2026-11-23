import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show AppLifecycleState;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/insight_source.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/providers/buddy_events_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/providers/insights_provider.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';
import 'package:belly_buddy/services/insights/insights_engine.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// The signed-in user's id, switchable.
class _UserId extends Notifier<String?> {
  @override
  String? build() => 'u1';

  void set(String? id) => state = id;
}

final _userIdProvider = NotifierProvider<_UserId, String?>(_UserId.new);

const _noEntries = InsightSource(
  meals: [],
  gutFeelings: [],
  activityInstants: [],
);

void main() {
  // The day signal's AppLifecycleListener needs the binding.
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  /// The app comes back to the foreground.
  void resume() => binding
    ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
    ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

  final now = DateTime(2026, 11, 23, 14);
  late FakeEntryRepository entryRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    entryRepo = FakeEntryRepository()
      ..insightSource = insightSourceFor(
        activeDays: 2,
        gutFeelings: 1,
        now: now,
      );
  });

  ProviderContainer makeContainer({DateTime Function()? clock}) =>
      ProviderContainer.test(
        overrides: [
          entryRepositoryProvider.overrideWithValue(entryRepo),
          buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
          currentUserIdProvider.overrideWith(
            (ref) => ref.watch(_userIdProvider),
          ),
          buddyClockProvider.overrideWithValue(clock ?? () => now),
        ],
      );

  InsightsNotifier notifier(ProviderContainer c) =>
      c.read(insightsProvider.notifier);

  test('loads and computes', () async {
    final source = insightSourceFor(activeDays: 7, gutFeelings: 3, now: now);
    entryRepo.insightSource = source;
    final c = makeContainer();

    final insights = await c.read(insightsProvider.future);

    expect(insights, computeInsights(source, now));
    expect(insights.unlocked, isTrue);
    expect(
      insights.progress,
      const InsightProgress(activeDays: 7, gutFeelingEntries: 3),
    );
    expect(insights.calendar.last.day, DateTime(2026, 11, 23));
    expect(entryRepo.insightSourceRequests, [(userId: 'u1', now: now)]);
  });

  test('signed out: the empty insights, nothing fetched', () async {
    final c = makeContainer();
    c.read(_userIdProvider.notifier).set(null);

    final insights = await c.read(insightsProvider.future);

    expect(insights, computeInsights(_noEntries, now));
    expect(insights.progress.activeDays, 0);
    expect(insights.progress.gutFeelingEntries, 0);
    expect(insights.calendar, hasLength(30));
    expect(insights.calendar.every((d) => d.dayClass == DayClass.none), isTrue);
    expect(insights.pick, const NothingYetPick());
    expect(entryRepo.insightSourceCalls, 0);
  });

  group('recomputes after any entry write', () {
    final writes = <String, Future<void> Function(EntriesNotifier)>{
      'a log': (e) => e.addGutFeeling(testGutFeelingEntry()),
      'an edit (a meal moved to another day)': (e) =>
          e.updateMeal(testMealEntry(trackedAt: DateTime(2026, 11, 20, 9))),
      'a delete': (e) => e.deleteByType('gutFeeling', 'g1'),
    };
    for (final MapEntry(key: name, value: write) in writes.entries) {
      test(name, () async {
        final c = makeContainer();
        await c.read(insightsProvider.future);
        final next = insightSourceFor(activeDays: 3, gutFeelings: 2, now: now);
        entryRepo.insightSource = next;

        await write(c.read(entriesProvider.notifier));
        await settle();

        expect(entryRepo.insightSourceCalls, 2);
        expect(c.read(insightsProvider).value, computeInsights(next, now));
      });
    }

    test('deleting the 3rd gut-feeling entry locks the insights again '
        '(no refresh needed)', () async {
      entryRepo.insightSource = insightSourceFor(
        activeDays: 7,
        gutFeelings: 3,
        now: now,
      );
      final c = makeContainer();
      expect((await c.read(insightsProvider.future)).unlocked, isTrue);
      entryRepo.insightSource = insightSourceFor(
        activeDays: 7,
        gutFeelings: 2,
        now: now,
      );

      await c.read(entriesProvider.notifier).deleteByType('gutFeeling', 'g3');
      await settle();

      expect(entryRepo.insightSourceCalls, 2);
      expect(c.read(insightsProvider).value!.unlocked, isFalse);
      expect(c.read(insightsProvider).value!.progress.gutFeelingsLeft, 1);
    });

    test('a write during the first load is fetched after it', () async {
      final before = insightSourceFor(activeDays: 7, gutFeelings: 3, now: now);
      final after = insightSourceFor(activeDays: 7, gutFeelings: 2, now: now);
      entryRepo.holdInsightSource = true;
      final c = makeContainer();
      c.listen(insightsProvider, (_, _) {});
      await settle();
      expect(entryRepo.heldInsightSources, hasLength(1));

      // The 3rd gut-feeling entry is deleted while the load runs.
      await c.read(entriesProvider.notifier).deleteByType('gutFeeling', 'g3');
      await settle();
      entryRepo
        ..holdInsightSource = false
        ..insightSource = after;
      // The load's fetch started before the delete.
      entryRepo.heldInsightSources.single.complete(before);
      await settle();

      expect(entryRepo.insightSourceCalls, 2);
      expect(c.read(insightsProvider).value, computeInsights(after, now));
      expect(c.read(insightsProvider).value!.unlocked, isFalse);
    });

    test('a write during a user change\'s load is fetched after it', () async {
      final c = makeContainer();
      c.listen(insightsProvider, (_, _) {});
      await c.read(insightsProvider.future);
      entryRepo.holdInsightSource = true;
      c.read(_userIdProvider.notifier).set('u2');
      await settle();

      await c
          .read(entriesProvider.notifier)
          .addGutFeeling(testGutFeelingEntry());
      await settle();
      final after = insightSourceFor(activeDays: 1, gutFeelings: 1, now: now);
      entryRepo
        ..holdInsightSource = false
        ..insightSource = after;
      entryRepo.heldInsightSources.single.complete(_noEntries);
      await settle();

      expect(entryRepo.insightSourceRequests.map((r) => r.userId), [
        'u1',
        'u2',
        'u2',
      ]);
      expect(c.read(insightsProvider).value, computeInsights(after, now));
    });

    test('a burst of writes during a fetch: one more fetch after it, with '
        'all of them', () async {
      final c = makeContainer();
      c.listen(insightsProvider, (_, _) {});
      await c.read(insightsProvider.future);
      entryRepo.holdInsightSource = true;
      final entries = c.read(entriesProvider.notifier);
      await entries.addGutFeeling(testGutFeelingEntry());
      await settle();
      expect(entryRepo.heldInsightSources, hasLength(1));

      // Three more writes while that fetch runs.
      await entries.addGutFeeling(testGutFeelingEntry());
      await entries.updateMeal(testMealEntry());
      await entries.deleteByType('gutFeeling', 'g1');
      await settle();
      expect(entryRepo.heldInsightSources, hasLength(1));

      final all = insightSourceFor(activeDays: 4, gutFeelings: 3, now: now);
      entryRepo
        ..holdInsightSource = false
        ..insightSource = all;
      // The running fetch started before the last three writes.
      entryRepo.heldInsightSources.single.complete(
        insightSourceFor(activeDays: 3, gutFeelings: 2, now: now),
      );
      await settle();

      // The load, the first write's fetch and one for the other three.
      expect(entryRepo.insightSourceCalls, 3);
      expect(c.read(insightsProvider).value, computeInsights(all, now));
    });

    test('a write that changes nothing in them notifies no one (the UI '
        'rebuilds nothing)', () async {
      final c = makeContainer();
      final heard = <AsyncValue<Insights>>[];
      c.listen(insightsProvider, (_, next) => heard.add(next));
      final loaded = await c.read(insightsProvider.future);
      heard.clear();
      // Equal entries, fetched anew.
      entryRepo.insightSource = insightSourceFor(
        activeDays: 2,
        gutFeelings: 1,
        now: now,
      );

      await c.read(entriesProvider.notifier).updateMeal(testMealEntry());
      await settle();

      expect(entryRepo.insightSourceCalls, 2);
      expect(heard, isEmpty);
      expect(c.read(insightsProvider).value, loaded);
    });

    test('a Buddy event alone (no write) fetches nothing', () async {
      final c = makeContainer();
      await c.read(insightsProvider.future);

      c
          .read(buddyEventsProvider.notifier)
          .emit(
            BuddyLogEvent(
              EntryKind.meal,
              LogSentiment.good,
              at: now,
              trackedAt: now,
            ),
          );
      await settle();

      expect(entryRepo.insightSourceCalls, 1);
    });
  });

  group('recomputes at local midnight', () {
    // 30 days ending 23 Nov start on 25 Oct; ending 24 Nov, on 26 Oct.
    final source = InsightSource(
      meals: const [],
      gutFeelings: const [],
      activityInstants: [DateTime(2026, 10, 25, 12), DateTime(2026, 11, 23, 9)],
    );
    final beforeMidnight = DateTime(2026, 11, 23, 23, 59, 30);

    test('the window moves: today is the new day, day 31 drops out, and '
        'the timer is armed again', () {
      fakeAsync((async) {
        entryRepo.insightSource = source;
        final c = makeContainer(clock: () => beforeMidnight.add(async.elapsed));
        c.listen(insightsProvider, (_, _) {});
        async.flushMicrotasks();

        final before = c.read(insightsProvider).value!;
        expect(before.calendar.first.day, DateTime(2026, 10, 25));
        expect(before.calendar.last.day, DateTime(2026, 11, 23));
        expect(before.progress.activeDays, 2);

        async.elapse(const Duration(seconds: 29));
        expect(entryRepo.insightSourceCalls, 1);

        async.elapse(const Duration(seconds: 2));
        expect(entryRepo.insightSourceCalls, 2);
        expect(
          entryRepo.insightSourceRequests.last.now,
          DateTime(2026, 11, 24),
        );
        final after = c.read(insightsProvider).value!;
        expect(after.calendar.first.day, DateTime(2026, 10, 26));
        expect(after.calendar.last.day, DateTime(2026, 11, 24));
        expect(after.progress.activeDays, 1);

        async.elapse(const Duration(hours: 24));
        expect(entryRepo.insightSourceCalls, 3);
        expect(
          entryRepo.insightSourceRequests.last.now,
          DateTime(2026, 11, 25),
        );
        expect(
          c.read(insightsProvider).value!.calendar.last.day,
          DateTime(2026, 11, 25),
        );
      });
    });

    test('midnight during a load: fetched again for the new day after it', () {
      fakeAsync((async) {
        entryRepo
          ..insightSource = source
          ..holdInsightSource = true;
        final c = makeContainer(clock: () => beforeMidnight.add(async.elapsed));
        c.listen(insightsProvider, (_, _) {});
        async.flushMicrotasks();
        expect(entryRepo.heldInsightSources, hasLength(1));

        // Midnight passes while the load (as of 23:59:30) still runs.
        async.elapse(const Duration(seconds: 31));
        entryRepo.holdInsightSource = false;
        entryRepo.heldInsightSources.single.complete(source);
        async.flushMicrotasks();

        expect(entryRepo.insightSourceCalls, 2);
        expect(
          entryRepo.insightSourceRequests.last.now,
          DateTime(2026, 11, 24, 0, 0, 1),
        );
        final value = c.read(insightsProvider).value!;
        expect(value.calendar.last.day, DateTime(2026, 11, 24));
        expect(value.progress.activeDays, 1);
      });
    });

    test('signed out, the empty calendar moves too (nothing fetched)', () {
      fakeAsync((async) {
        final c = makeContainer(clock: () => beforeMidnight.add(async.elapsed));
        c.read(_userIdProvider.notifier).set(null);
        c.listen(insightsProvider, (_, _) {});
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 31));

        expect(
          c.read(insightsProvider).value!.calendar.last.day,
          DateTime(2026, 11, 24),
        );
        expect(entryRepo.insightSourceCalls, 0);
      });
    });

    test('unwatched over midnight (Home hidden): nothing fetched meanwhile, '
        'recomputed once watched again', () {
      fakeAsync((async) {
        entryRepo.insightSource = source;
        final c = makeContainer(clock: () => beforeMidnight.add(async.elapsed));
        final sub = c.listen(insightsProvider, (_, _) {});
        async.flushMicrotasks();

        sub.pause();
        async.elapse(const Duration(hours: 1));
        expect(entryRepo.insightSourceCalls, 1);

        sub.resume();
        async.flushMicrotasks();
        expect(entryRepo.insightSourceCalls, 2);
        expect(
          c.read(insightsProvider).value!.calendar.last.day,
          DateTime(2026, 11, 24),
        );

        // Armed again for the next midnight (25 Nov, in 23 h 0 min 30 s).
        async.elapse(const Duration(hours: 23));
        expect(entryRepo.insightSourceCalls, 2);
        async.elapse(const Duration(seconds: 31));
        expect(entryRepo.insightSourceCalls, 3);
        expect(
          entryRepo.insightSourceRequests.last.now,
          DateTime(2026, 11, 25),
        );
      });
    });

    test('unwatched and watched again on the same day: nothing fetched', () {
      fakeAsync((async) {
        final c = makeContainer(clock: () => now.add(async.elapsed));
        final sub = c.listen(insightsProvider, (_, _) {});
        async.flushMicrotasks();

        sub.pause();
        async.elapse(const Duration(hours: 1));
        sub.resume();
        async.flushMicrotasks();

        expect(entryRepo.insightSourceCalls, 1);
      });
    });

    test('disposed: the timer is gone', () {
      fakeAsync((async) {
        final c = makeContainer(clock: () => beforeMidnight.add(async.elapsed));
        c.listen(insightsProvider, (_, _) {});
        async.flushMicrotasks();
        expect(async.pendingTimers, isNotEmpty);

        c.dispose();

        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  group('back in the foreground (the midnight timer stood still while the '
      'device slept)', () {
    final source = InsightSource(
      meals: const [],
      gutFeelings: const [],
      activityInstants: [DateTime(2026, 10, 25, 12), DateTime(2026, 11, 23, 9)],
    );
    final beforeMidnight = DateTime(2026, 11, 23, 23, 59, 30);

    test('past midnight: computed for the new day, the timer armed for the '
        'next one', () {
      fakeAsync((async) {
        // The clock moves on while asleep; fake timers only with elapse.
        var asleep = Duration.zero;
        entryRepo.insightSource = source;
        final c = makeContainer(
          clock: () => beforeMidnight.add(async.elapsed + asleep),
        );
        c.listen(insightsProvider, (_, _) {});
        async.flushMicrotasks();

        asleep = const Duration(hours: 8);
        resume();
        async.flushMicrotasks();

        expect(entryRepo.insightSourceCalls, 2);
        expect(
          entryRepo.insightSourceRequests.last.now,
          DateTime(2026, 11, 24, 7, 59, 30),
        );
        expect(
          c.read(insightsProvider).value!.calendar.last.day,
          DateTime(2026, 11, 24),
        );

        // The late timer is gone: nothing more when it would have fired …
        async.elapse(const Duration(seconds: 31));
        expect(entryRepo.insightSourceCalls, 2);
        // … and the next midnight (25 Nov, 16 h 0 min 30 s after waking)
        // fires.
        async.elapse(const Duration(hours: 16));
        expect(entryRepo.insightSourceCalls, 3);
        expect(
          entryRepo.insightSourceRequests.last.now,
          DateTime(2026, 11, 25),
        );
      });
    });

    test('the same day: nothing fetched', () {
      fakeAsync((async) {
        final c = makeContainer(clock: () => now.add(async.elapsed));
        c.listen(insightsProvider, (_, _) {});
        async.flushMicrotasks();

        resume();
        async.flushMicrotasks();

        expect(entryRepo.insightSourceCalls, 1);
      });
    });

    test('unwatched: nothing until watched again', () {
      fakeAsync((async) {
        var asleep = Duration.zero;
        entryRepo.insightSource = source;
        final c = makeContainer(
          clock: () => beforeMidnight.add(async.elapsed + asleep),
        );
        final sub = c.listen(insightsProvider, (_, _) {});
        async.flushMicrotasks();
        sub.pause();
        async.flushMicrotasks();

        asleep = const Duration(hours: 8);
        resume();
        async.flushMicrotasks();
        expect(entryRepo.insightSourceCalls, 1);

        sub.resume();
        async.flushMicrotasks();
        expect(entryRepo.insightSourceCalls, 2);
        expect(
          c.read(insightsProvider).value!.calendar.last.day,
          DateTime(2026, 11, 24),
        );
      });
    });
  });

  group('refresh', () {
    test('during the first load it joins it', () async {
      final c = makeContainer();
      c.read(insightsProvider);

      await notifier(c).refresh();

      expect(entryRepo.insightSourceCalls, 1);
      expect(c.read(insightsProvider).hasValue, isTrue);
    });

    test(
      'a newer refresh wins over an older one that finishes later',
      () async {
        final c = makeContainer();
        await c.read(insightsProvider.future);
        entryRepo.holdInsightSource = true;
        final older = insightSourceFor(activeDays: 3, gutFeelings: 1, now: now);
        final newer = insightSourceFor(activeDays: 4, gutFeelings: 2, now: now);

        final first = notifier(c).refresh();
        final second = notifier(c).refresh();
        await settle();
        expect(entryRepo.heldInsightSources, hasLength(2));

        entryRepo.heldInsightSources[1].complete(newer);
        await second;
        expect(c.read(insightsProvider).value, computeInsights(newer, now));

        entryRepo.heldInsightSources[0].complete(older);
        await first;
        expect(c.read(insightsProvider).value, computeInsights(newer, now));
      },
    );

    test('a failed refresh keeps the last value and never throws', () async {
      final c = makeContainer();
      final loaded = await c.read(insightsProvider.future);
      entryRepo.insightSourceError = Exception('offline');

      await notifier(c).refresh();

      expect(c.read(insightsProvider), isA<AsyncData<Insights>>());
      expect(c.read(insightsProvider).value, loaded);
    });

    test('a failed first load is an error, without retries; a later '
        'refresh recovers', () {
      fakeAsync((async) {
        entryRepo.insightSourceError = Exception('offline');
        final c = makeContainer(clock: () => now.add(async.elapsed));
        c.listen(insightsProvider, (_, _) {});
        async.flushMicrotasks();
        expect(c.read(insightsProvider).hasError, isTrue);
        expect(c.read(insightsProvider).hasValue, isFalse);

        // No automatic retry.
        async.elapse(const Duration(minutes: 1));
        expect(entryRepo.insightSourceCalls, 1);

        // A failing refresh leaves the error and doesn't throw.
        Object? thrown;
        notifier(c).refresh().catchError((Object e) => thrown = e);
        async.flushMicrotasks();
        expect(thrown, isNull);
        expect(c.read(insightsProvider).hasError, isTrue);

        entryRepo.insightSourceError = null;
        notifier(c).refresh();
        async.flushMicrotasks();
        expect(c.read(insightsProvider), isA<AsyncData<Insights>>());
      });
    });
  });

  group('a user change never shows the previous user\'s insights', () {
    final a = insightSourceFor(activeDays: 7, gutFeelings: 3, now: now);
    final b = insightSourceFor(activeDays: 1, gutFeelings: 0, now: now);

    test(
      'while the new user\'s insights load, the state is reloading',
      () async {
        entryRepo.insightSource = a;
        final c = makeContainer();
        c.listen(insightsProvider, (_, _) {});
        await c.read(insightsProvider.future);
        entryRepo.holdInsightSource = true;

        c.read(_userIdProvider.notifier).set('u2');
        await settle();

        final reloading = c.read(insightsProvider);
        expect(reloading.isReloading, isTrue);
        expect(reloading, isNot(isA<AsyncData<Insights>>()));
        expect(entryRepo.insightSourceRequests.last.userId, 'u2');

        entryRepo.heldInsightSources.single.complete(b);
        await settle();

        final loaded = c.read(insightsProvider);
        expect(loaded.isReloading, isFalse);
        expect(loaded.value, computeInsights(b, now));
      },
    );

    test('a refresh during the new user\'s load joins it', () async {
      entryRepo.insightSource = a;
      final c = makeContainer();
      c.listen(insightsProvider, (_, _) {});
      await c.read(insightsProvider.future);
      entryRepo.holdInsightSource = true;
      c.read(_userIdProvider.notifier).set('u2');
      await settle();

      final refresh = notifier(c).refresh();
      await settle();
      entryRepo.heldInsightSources.single.complete(b);
      await refresh;

      expect(entryRepo.insightSourceCalls, 2);
      expect(c.read(insightsProvider).value, computeInsights(b, now));
    });

    test('the new user\'s failed first load is an error, never the previous '
        'user\'s data', () async {
      entryRepo.insightSource = a;
      final c = makeContainer();
      c.listen(insightsProvider, (_, _) {});
      await c.read(insightsProvider.future);
      entryRepo.insightSourceError = Exception('offline');

      c.read(_userIdProvider.notifier).set('u2');
      await settle();

      final failed = c.read(insightsProvider);
      expect(failed.hasError, isTrue);
      expect(failed, isNot(isA<AsyncData<Insights>>()));
    });

    test(
      'the previous user\'s refresh that finishes late is dropped',
      () async {
        entryRepo.insightSource = a;
        final c = makeContainer();
        c.listen(insightsProvider, (_, _) {});
        await c.read(insightsProvider.future);
        entryRepo.holdInsightSource = true;
        final late = notifier(c).refresh();
        await settle();

        c.read(_userIdProvider.notifier).set('u2');
        await settle();
        entryRepo.heldInsightSources[1].complete(b);
        await settle();
        entryRepo.heldInsightSources[0].complete(a);
        await late;
        await settle();

        expect(entryRepo.insightSourceRequests.map((r) => r.userId), [
          'u1',
          'u1',
          'u2',
        ]);
        expect(c.read(insightsProvider).value, computeInsights(b, now));
      },
    );

    test('a refresh that finishes after the user changed, before the '
        'insights rebuilt (unwatched), is dropped', () async {
      entryRepo.insightSource = a;
      final c = makeContainer();
      final sub = c.listen(insightsProvider, (_, _) {});
      await c.read(insightsProvider.future);
      entryRepo.holdInsightSource = true;
      final late = notifier(c).refresh();
      await settle();

      // Unwatched, the provider rebuilds for u2 only when read again.
      sub.pause();
      c.read(_userIdProvider.notifier).set('u2');
      entryRepo.heldInsightSources[0].complete(
        insightSourceFor(activeDays: 9, gutFeelings: 9, now: now),
      );
      await late;

      // Read again: reloading for u2, still holding u1's loaded value, not
      // the late one.
      expect(c.read(insightsProvider).isReloading, isTrue);
      expect(c.read(insightsProvider).value, computeInsights(a, now));
      entryRepo.heldInsightSources[1].complete(b);
      await settle();
      expect(c.read(insightsProvider).value, computeInsights(b, now));
    });

    test(
      'sign-out gives the empty insights, sign-in the new user\'s',
      () async {
        entryRepo.insightSource = a;
        final c = makeContainer();
        c.listen(insightsProvider, (_, _) {});
        await c.read(insightsProvider.future);

        c.read(_userIdProvider.notifier).set(null);
        await settle();
        expect(
          c.read(insightsProvider).value,
          computeInsights(_noEntries, now),
        );

        entryRepo.insightSource = b;
        c.read(_userIdProvider.notifier).set('u2');
        await settle();
        expect(c.read(insightsProvider).value, computeInsights(b, now));
        expect(entryRepo.insightSourceCalls, 2);
      },
    );
  });
}
