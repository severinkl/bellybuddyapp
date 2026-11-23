import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/today_provider.dart';

void main() {
  // The provider's AppLifecycleListener needs the binding.
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  void resume() => binding
    ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
    ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

  final beforeMidnight = DateTime(2026, 11, 23, 23, 59, 30);

  /// A container whose clock reads [clock]; every day [todayProvider]
  /// announces is recorded in the returned list.
  (ProviderContainer, List<DateTime>) makeContainer(DateTime Function() clock) {
    final c = ProviderContainer.test(
      overrides: [buddyClockProvider.overrideWithValue(clock)],
    );
    final days = <DateTime>[];
    c.listen(todayProvider, (_, day) => days.add(day));
    return (c, days);
  }

  test('today is the local date at midnight', () {
    final (c, _) = makeContainer(() => DateTime(2026, 11, 23, 14, 5));

    expect(c.read(todayProvider), DateTime(2026, 11, 23));
  });

  test('moves on at local midnight, and again at the next one', () {
    fakeAsync((async) {
      final (c, days) = makeContainer(() => beforeMidnight.add(async.elapsed));

      async.elapse(const Duration(seconds: 29));
      expect(days, isEmpty);

      async.elapse(const Duration(seconds: 1));
      expect(days, [DateTime(2026, 11, 24)]);
      expect(c.read(todayProvider), DateTime(2026, 11, 24));

      async.elapse(const Duration(hours: 24));
      expect(days, [DateTime(2026, 11, 24), DateTime(2026, 11, 25)]);
    });
  });

  test('a timer that fires before the clock passed midnight waits on, '
      'without a change', () {
    fakeAsync((async) {
      var lag = Duration.zero;
      final (_, days) = makeContainer(
        () => beforeMidnight.add(async.elapsed - lag),
      );

      // The clock falls a second behind the timers.
      lag = const Duration(seconds: 1);
      async.elapse(const Duration(seconds: 30));
      expect(days, isEmpty);

      async.elapse(const Duration(seconds: 1));
      expect(days, [DateTime(2026, 11, 24)]);
    });
  });

  group('back in the foreground (timers stood still while the device '
      'slept)', () {
    test('past midnight: moves on, and the timer is armed for the next one '
        'instead of the late one', () {
      fakeAsync((async) {
        // The clock moves on while asleep; fake timers only with elapse.
        var asleep = Duration.zero;
        final (_, days) = makeContainer(
          () => beforeMidnight.add(async.elapsed + asleep),
        );

        asleep = const Duration(hours: 8);
        resume();
        expect(days, [DateTime(2026, 11, 24)]);

        // Nothing when the late timer would have fired …
        async.elapse(const Duration(seconds: 31));
        expect(days, hasLength(1));
        // … and the next midnight (25 Nov, 16 h 0 min 30 s after waking)
        // moves on.
        async.elapse(const Duration(hours: 16));
        expect(days, [DateTime(2026, 11, 24), DateTime(2026, 11, 25)]);
      });
    });

    test('the same day: nothing', () {
      fakeAsync((async) {
        final (_, days) = makeContainer(
          () => DateTime(2026, 11, 23, 14).add(async.elapsed),
        );

        resume();
        async.flushMicrotasks();

        expect(days, isEmpty);
      });
    });

    test('a paused listener hears of the new day once it resumes', () {
      fakeAsync((async) {
        var asleep = Duration.zero;
        final (c, _) = makeContainer(
          () => beforeMidnight.add(async.elapsed + asleep),
        );
        final heard = <DateTime>[];
        final sub = c.listen(todayProvider, (_, day) => heard.add(day));
        sub.pause();

        asleep = const Duration(hours: 8);
        resume();
        expect(heard, isEmpty);

        sub.resume();
        expect(heard, [DateTime(2026, 11, 24)]);
      });
    });
  });

  test('disposed: the timer is gone and resumes are ignored', () {
    fakeAsync((async) {
      final (c, _) = makeContainer(() => beforeMidnight.add(async.elapsed));
      expect(async.pendingTimers, hasLength(1));

      c.dispose();
      resume();

      expect(async.pendingTimers, isEmpty);
    });
  });
}
