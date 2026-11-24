import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_foreground_provider.dart';
import 'buddy_provider.dart';

/// The app's clock ([buddyClockProvider]) to the minute: what Home's
/// meters, mood and lines are seen from ([careNowProvider]).
///
/// Moves on at each minute boundary of the clock (one timer to the next)
/// and, since timers stand still while an iOS device sleeps, when the app
/// is back in the foreground ([appForegroundProvider]). Unchanged within a
/// minute, so a listener hears of each minute once.
class MinuteNotifier extends Notifier<DateTime> {
  Timer? _tick;

  @override
  DateTime build() {
    final clock = ref.watch(buddyClockProvider);
    ref
      ..listen(appForegroundProvider, (_, _) => _check())
      ..onDispose(() => _tick?.cancel());
    return _arm(clock());
  }

  void _check() => state = _arm(ref.read(buddyClockProvider)());

  /// Arms the timer for the minute after [now] and returns [now]'s minute.
  /// Counted back from [now] rather than rebuilt from its fields: in the
  /// hour that repeats when the clocks go back, the fields name its first
  /// time, an hour before [now].
  DateTime _arm(DateTime now) {
    final intoMinute = Duration(
      seconds: now.second,
      milliseconds: now.millisecond,
      microseconds: now.microsecond,
    );
    _tick?.cancel();
    _tick = Timer(const Duration(minutes: 1) - intoMinute, _check);
    return now.subtract(intoMinute);
  }
}

final minuteProvider = NotifierProvider<MinuteNotifier, DateTime>(
  MinuteNotifier.new,
);
