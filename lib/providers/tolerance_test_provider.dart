import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pattern_stats.dart';
import '../models/tolerance_test.dart';
import '../repositories/tolerance_test_repository.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';
import 'pattern_stats_provider.dart';
import 'plus_provider.dart';
import 'today_provider.dart';

export '../repositories/tolerance_test_repository.dart'
    show TestConflict, toleranceStartsOnWire;

const _log = AppLogger('ToleranceTest');

/// The test reminders (spec §5.5, ids 3000/3001). A no-op here; IA5
/// overrides [toleranceTestRemindersProvider] with one backed by
/// `LocalNotificationService.scheduleTestReminders/cancelTestReminders`.
class ToleranceTestReminders {
  const ToleranceTestReminders();

  /// Schedules [test]'s reminders (first reintroduction day and result day).
  Future<void> schedule(ToleranceTestView test) async {}

  /// Cancels the test reminders.
  Future<void> cancel() async {}
}

final toleranceTestRemindersProvider = Provider<ToleranceTestReminders>(
  (ref) => const ToleranceTestReminders(),
);

enum StartOutcome {
  started,

  /// Another test is active; the stats were reloaded and show it.
  conflict,

  /// Nothing was started: a failure, or Plus/the stats are locked or the
  /// restrictive guard holds (the UI offers no „Testen" then).
  failed,
}

/// Starts, stops and completes the signed-in user's tolerance test. Every
/// action does nothing while Plus ([plusLockedProvider]) or the stats
/// ([PatternStatsStateX.isLocked]) are locked.
class ToleranceTestActions {
  ToleranceTestActions(this._ref);

  final Ref _ref;

  /// Completions under way or done in this app run, by test id: each test
  /// is completed once, however often the stats arrive.
  final _completions = <String, Future<bool>>{};

  bool get _locked =>
      _ref.read(plusLockedProvider) || _ref.read(patternStatsProvider).isLocked;

  Future<void> _refresh() => _ref.read(patternStatsProvider.notifier).refresh();

  /// Starts a test of [s] tomorrow (the wall-clock date after
  /// [todayProvider]'s day), schedules its reminders and refreshes the
  /// stats. An active test past its end is completed first (the
  /// one-active-test index would reject the insert otherwise).
  Future<StartOutcome> start(TestSubject s, {required String origin}) async {
    if (_locked) return StartOutcome.failed;
    final stats = _ref.read(patternStatsProvider).value;
    if (stats?.restrictive ?? false) return StartOutcome.failed;
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return StartOutcome.failed;
    if (!await completeIfDone(stats?.test)) return StartOutcome.failed;

    final startsOn = addDays(_ref.read(todayProvider), 1);
    try {
      await _ref
          .read(toleranceTestRepositoryProvider)
          .start(s, origin: origin, startsOn: startsOn);
    } on TestConflict {
      _log.debug('start: another test is active');
      await _refresh();
      return StartOutcome.conflict;
    } catch (e) {
      // The type only: an error's details may carry the subject.
      _log.error('start failed: ${e.runtimeType}');
      return StartOutcome.failed;
    }
    await _refresh();
    if (!_ref.isCurrentUser(userId)) return StartOutcome.started;
    final test = _ref.read(patternStatsProvider).value?.test;
    if (test != null &&
        test.isActive &&
        test.subject.kind == s.kind &&
        test.subject.key == s.key) {
      try {
        await _ref.read(toleranceTestRemindersProvider).schedule(test);
      } catch (e, st) {
        _log.error('scheduling the test reminders failed', e, st);
      }
    }
    return StartOutcome.started;
  }

  /// Stops the test (`stopped`, `ended_at` now), cancels its reminders and
  /// refreshes the stats. Throws when the stop fails (reminders kept).
  Future<void> stop(String id) async {
    if (_locked) return;
    await _ref.read(toleranceTestRepositoryProvider).stop(id);
    try {
      await _ref.read(toleranceTestRemindersProvider).cancel();
    } catch (e, st) {
      _log.error('cancelling the test reminders failed', e, st);
    }
    await _refresh();
  }

  /// Completes [test] when it is still active but over (`phase: done`),
  /// once per test, then refreshes the stats. True unless that completion
  /// failed (a later call tries again).
  Future<bool> completeIfDone(ToleranceTestView? test) {
    if (test == null || !test.isActive || test.phase != TestPhase.done) {
      return Future.value(true);
    }
    if (_locked) return Future.value(false);
    return _completions[test.id] ??= _complete(test.id);
  }

  Future<bool> _complete(String id) async {
    try {
      await _ref.read(toleranceTestRepositoryProvider).complete(id);
    } catch (e) {
      _log.error('completing the test failed: ${e.runtimeType}');
      _completions.remove(id);
      return false;
    }
    unawaited(_refresh());
    return true;
  }
}

final toleranceTestActionsProvider = Provider<ToleranceTestActions>(
  ToleranceTestActions.new,
);

/// Starts a test of [s] tomorrow (local), schedules its reminders (IA5),
/// refreshes [patternStatsProvider].
Future<StartOutcome> startToleranceTest(
  WidgetRef ref,
  TestSubject s, {
  required String origin,
}) => ref.read(toleranceTestActionsProvider).start(s, origin: origin);

/// Stops the test, cancels its reminders, refreshes the stats. Throws when
/// the stop fails.
Future<void> stopToleranceTest(WidgetRef ref, String id) =>
    ref.read(toleranceTestActionsProvider).stop(id);

/// Listens to [patternStatsProvider]: the first time a test arrives with
/// phase done and status active, completes it. Watched from the app shell;
/// while Plus is locked it does not listen (no stats load for it).
final toleranceTestCompleterProvider = Provider<void>((ref) {
  if (ref.watch(plusLockedProvider)) return;
  ref.listen<AsyncValue<PatternStats?>>(patternStatsProvider, (_, next) {
    // While loading (a user change) the value may be the previous user's.
    if (next.isLoading || next.isLocked) return;
    final test = next.value?.test;
    if (test == null) return;
    unawaited(ref.read(toleranceTestActionsProvider).completeIfDone(test));
  }, fireImmediately: true);
});
