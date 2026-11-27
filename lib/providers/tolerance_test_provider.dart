import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pattern_stats.dart';
import '../models/tolerance_test.dart';
import '../repositories/notification_repository.dart';
import '../repositories/tolerance_test_repository.dart';
import '../services/insights/test_copy.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';
import 'pattern_stats_provider.dart';
import 'plus_provider.dart';
import 'today_provider.dart';

export '../repositories/tolerance_test_repository.dart' show TestConflict;

const _log = AppLogger('ToleranceTest');

/// The test reminders (spec §5.5): local notifications at 09:00 on the
/// first reintroduction day and on the result day
/// ([NotificationRepository.scheduleTestReminders]), only while the OS
/// permission is already granted (no new ask).
class ToleranceTestReminders {
  const ToleranceTestReminders(this._notifications);

  final NotificationRepository _notifications;

  /// Schedules [test]'s reminders (first reintroduction day and result
  /// day), replacing pending ones; without the permission none. True when
  /// they were scheduled.
  Future<bool> schedule(ToleranceTestView test) async {
    if (await _notifications.permissionStatus() !=
        NotificationPermission.granted) {
      _log.debug('test reminders: no permission, none scheduled');
      return false;
    }
    await _notifications.scheduleTestReminders(
      reintroBody: TestCopy.reintroNotification(test.subject),
      reintroDay: test.reintroStartsOn,
      resultDay: test.resultDay,
    );
    return true;
  }

  /// Cancels the test reminders.
  Future<void> cancel() => _notifications.cancelTestReminders();
}

final toleranceTestRemindersProvider = Provider<ToleranceTestReminders>(
  (ref) => ToleranceTestReminders(ref.watch(notificationRepositoryProvider)),
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

  /// The reminder schedulings under way or done in this app run, by test
  /// id, since the last [forgetScheduled] or [cancelReminders]: each test
  /// is scheduled once. One that scheduled nothing (no permission, a
  /// failure) is dropped, so the next sight tries again.
  final _scheduled = <String, Future<bool>>{};

  /// The reminders were cancelled since an active test was last seen.
  bool _cancelled = false;

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
      await _scheduleOnce(test);
    }
    return StartOutcome.started;
  }

  /// Stops the test (`stopped`, `ended_at` now), cancels its reminders and
  /// refreshes the stats. Throws when the stop fails (reminders kept).
  Future<void> stop(String id) async {
    if (_locked) return;
    await _ref.read(toleranceTestRepositoryProvider).stop(id);
    await cancelReminders();
    await _refresh();
  }

  /// Schedules [test]'s reminders again once per app run while it is
  /// active and not over (they may be missing: a re-install, a sign-out's
  /// `cancelAll`); past days schedule nothing.
  Future<void> rescheduleIfRunning(ToleranceTestView? test) async {
    if (test == null || !test.isActive || test.phase == TestPhase.done) {
      return;
    }
    if (_locked) return;
    await _scheduleOnce(test);
  }

  /// Another user, or Plus switched: the next active test seen is
  /// scheduled again, and the next sight of none cancels again.
  void forgetScheduled() {
    _scheduled.clear();
    _cancelled = false;
  }

  /// Loaded stats of the current user: an active test (or one this build
  /// cannot read) keeps the reminders; none (stopped or completed on
  /// another device) cancels them, once until an active test is seen again.
  void cancelUnlessActive(PatternStats stats) {
    if ((stats.test?.isActive ?? false) || stats.hasUnreadableTest) {
      _cancelled = false;
    } else if (!_cancelled) {
      unawaited(cancelReminders());
    }
  }

  /// Schedules [test]'s reminders unless they were (or are being) in this
  /// run; counts as done only once they really were (no permission or a
  /// failure: tried again on the next sight).
  Future<void> _scheduleOnce(ToleranceTestView test) {
    final id = test.id;
    final running = _scheduled[id];
    if (running != null) return running;
    late final Future<bool> scheduling;
    scheduling = _schedule(test).then((ok) {
      // A cancel since may have dropped it, and a newer one taken its place.
      if (!ok && identical(_scheduled[id], scheduling)) _scheduled.remove(id);
      return ok;
    });
    return _scheduled[id] = scheduling;
  }

  Future<bool> _schedule(ToleranceTestView test) async {
    try {
      return await _ref.read(toleranceTestRemindersProvider).schedule(test);
    } catch (e) {
      // The type only: an error's details may carry the subject.
      _log.error('scheduling the test reminders failed: ${e.runtimeType}');
      return false;
    }
  }

  /// Cancels the test reminders (stop, completion, Plus locked, no active
  /// test seen); never throws. The next active test seen is scheduled
  /// again.
  Future<void> cancelReminders() async {
    _cancelled = true;
    _scheduled.clear();
    try {
      await _ref.read(toleranceTestRemindersProvider).cancel();
    } catch (e, st) {
      _log.error('cancelling the test reminders failed', e, st);
    }
  }

  /// Completes [test] when it is still active but over (`phase: done`),
  /// once per test, cancels its reminders, then refreshes the stats. True unless that completion
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
    await cancelReminders();
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
/// phase done and status active, completes it; an active test still
/// running gets its reminders scheduled again, once per app run and user
/// ([ToleranceTestActions.rescheduleIfRunning]); none active (stopped or
/// completed elsewhere) cancels them once
/// ([ToleranceTestActions.cancelUnlessActive]). Watched from the app
/// shell; while Plus is locked it cancels pending test reminders and does
/// not listen (no stats load for it).
final toleranceTestCompleterProvider = Provider<void>((ref) {
  ref.watch(currentUserIdProvider);
  final actions = ref.read(toleranceTestActionsProvider)..forgetScheduled();
  // Known locked (an unknown status reads open): no test reminders.
  if (ref.watch(plusLockedProvider)) {
    unawaited(actions.cancelReminders());
    return;
  }
  ref.listen<AsyncValue<PatternStats?>>(patternStatsProvider, (_, next) {
    // While loading (a user change) the value may be the previous user's.
    if (next.isLoading || next.isLocked) return;
    final stats = next.value;
    if (stats == null) return;
    actions.cancelUnlessActive(stats);
    final test = stats.test;
    if (test == null) return;
    unawaited(actions.completeIfDone(test));
    unawaited(actions.rescheduleIfRunning(test));
  }, fireImmediately: true);
});

/// Whether „Test starten" / „Testen" may be offered by the stats: loaded
/// ([AsyncData], not a reload or another user's value), not locked, not
/// restrictive, and no active test (also none past its end that is not
/// completed yet: the one-active-test index would reject the start; nor one
/// this build cannot read).
bool canOfferTest(AsyncValue<PatternStats?> stats) {
  // A rebuild (a user change) is an AsyncData that is still loading, with
  // the previous value.
  if (stats is! AsyncData<PatternStats?> || stats.isLoading) {
    return false;
  }
  final s = stats.value;
  if (s == null || s.restrictive || s.hasUnreadableTest) return false;
  return !(s.test?.isActive ?? false);
}

/// [canOfferTest] for the current state, with Plus open.
final canOfferTestProvider = Provider.autoDispose<bool>((ref) {
  // Both watched, locked or not (as before the split).
  final plusLocked = ref.watch(plusLockedProvider);
  final stats = ref.watch(patternStatsProvider);
  return !plusLocked && canOfferTest(stats);
});
