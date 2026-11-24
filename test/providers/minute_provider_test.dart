import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/minute_provider.dart';

import '../helpers/app_lifecycle.dart';

void main() {
  // The foreground signal's AppLifecycleListener needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  final start = DateTime(2026, 11, 23, 14, 5, 42);

  /// A container whose clock reads [clock]; every minute [minuteProvider]
  /// announces is recorded in the returned list.
  (ProviderContainer, List<DateTime>) makeContainer(DateTime Function() clock) {
    final c = ProviderContainer.test(
      overrides: [buddyClockProvider.overrideWithValue(clock)],
    );
    final minutes = <DateTime>[];
    c.listen(minuteProvider, (_, minute) => minutes.add(minute));
    return (c, minutes);
  }

  test("the clock's minute", () {
    final (c, _) = makeContainer(() => start);

    expect(c.read(minuteProvider), DateTime(2026, 11, 23, 14, 5));
  });

  test('ticks on the minute boundaries of the clock', () {
    fakeAsync((async) {
      final (_, minutes) = makeContainer(() => start.add(async.elapsed));

      async.elapse(const Duration(seconds: 17));
      expect(minutes, isEmpty);

      async.elapse(const Duration(seconds: 1));
      expect(minutes, [DateTime(2026, 11, 23, 14, 6)]);

      async.elapse(const Duration(minutes: 1));
      expect(minutes, [
        DateTime(2026, 11, 23, 14, 6),
        DateTime(2026, 11, 23, 14, 7),
      ]);
    });
  });

  // Under TZ=Europe/Vienna: 25 Oct 2026, the clocks went back at 03:00
  // CEST, so 02:30 comes twice. 02:30:20 CET is its second time.
  test('the repeated hour when the clocks go back: the minute of the clock, '
      'the next tick at most a minute away', () {
    fakeAsync((async) {
      final secondTime = DateTime.utc(2026, 10, 25, 1, 30, 20).toLocal();
      final (c, minutes) = makeContainer(() => secondTime.add(async.elapsed));

      expect(
        c.read(minuteProvider),
        DateTime.utc(2026, 10, 25, 1, 30).toLocal(),
      );
      final delay = async.pendingTimers.single.duration;
      expect(delay, const Duration(seconds: 40));

      async.elapse(const Duration(seconds: 39));
      expect(minutes, isEmpty);
      async.elapse(const Duration(seconds: 1));
      expect(minutes, [DateTime.utc(2026, 10, 25, 1, 31).toLocal()]);
      expect(async.pendingTimers, hasLength(1));
    });
  });

  group('back in the foreground (timers stood still while the device '
      'slept)', () {
    test('a later minute: announced at once', () {
      fakeAsync((async) {
        var asleep = Duration.zero;
        final (_, minutes) = makeContainer(
          () => start.add(async.elapsed + asleep),
        );

        asleep = const Duration(hours: 2);
        returnFromBackground();

        expect(minutes, [DateTime(2026, 11, 23, 16, 5)]);
      });
    });

    test('the same minute: nothing', () {
      fakeAsync((async) {
        final (_, minutes) = makeContainer(() => start.add(async.elapsed));

        async.elapse(const Duration(seconds: 5));
        returnFromBackground();
        async.flushMicrotasks();

        expect(minutes, isEmpty);
      });
    });
  });

  test('disposed: the timer is gone', () {
    fakeAsync((async) {
      final (c, _) = makeContainer(() => start.add(async.elapsed));
      expect(async.pendingTimers, hasLength(1));

      c.dispose();

      expect(async.pendingTimers, isEmpty);
    });
  });
}
