import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/date_format_utils.dart';
import 'buddy_provider.dart';

/// Today by the app's clock ([buddyClockProvider]): the local date, at
/// midnight. The one signal that the day changed; whatever follows the day
/// listens to it (the insights' window, Home's entries).
///
/// Moves on at local midnight (one timer to the next, armed by the
/// calendar so a DST change can't shift it) and, since timers stand still
/// while an iOS device sleeps, when the app is back in the foreground.
/// Unchanged otherwise, so a listener hears of a new day once; a paused one
/// hears of the latest once it resumes (Riverpod replays it).
class TodayNotifier extends Notifier<DateTime> {
  Timer? _midnight;

  @override
  DateTime build() {
    final clock = ref.watch(buddyClockProvider);
    final lifecycle = AppLifecycleListener(onResume: _check);
    ref.onDispose(() {
      _midnight?.cancel();
      lifecycle.dispose();
    });
    return _arm(clock());
  }

  /// Today as of now; equal to the state on the same day, so listeners hear
  /// nothing then.
  void _check() => state = _arm(ref.read(buddyClockProvider)());

  /// Arms the timer for the midnight after [now] and returns [now]'s day.
  DateTime _arm(DateTime now) {
    final local = now.toLocal();
    final today = startOfDay(local);
    _midnight?.cancel();
    _midnight = Timer(addDays(today, 1).difference(local), _check);
    return today;
  }
}

final todayProvider = NotifierProvider<TodayNotifier, DateTime>(
  TodayNotifier.new,
);
