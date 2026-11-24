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
  DateTime _arm(DateTime now) {
    final minute = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _tick?.cancel();
    _tick = Timer(
      minute.add(const Duration(minutes: 1)).difference(now),
      _check,
    );
    return minute;
  }
}

final minuteProvider = NotifierProvider<MinuteNotifier, DateTime>(
  MinuteNotifier.new,
);
