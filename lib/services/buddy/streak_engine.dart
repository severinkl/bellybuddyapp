import 'dart:math' as math;

import '../../models/buddy_state.dart';
import '../../utils/date_format_utils.dart';

/// Maximum number of streak savers a user can hold.
const int maxStreakSavers = 2;

/// Every multiple of this many streak days is a milestone worth one saver.
const int streakMilestoneDays = 7;

/// A run must be at least this long to be "saved" by savers or reported as
/// broken.
const int _minRunToProtect = 2;

/// Result of [evaluateStreak].
class StreakEvaluation {
  const StreakEvaluation({
    required this.streak,
    required this.todayCounted,
    required this.consumedDays,
    required this.refundedDays,
    required this.next,
    required this.saversEarned,
    required this.goalReached,
    required this.streakBroken,
    required this.reachesWindow,
    required BuddyState previous,
    this.milestoneReached,
    this.brokenAfter,
  }) : _previous = previous;

  /// Consecutive counted days (activity or saved) ending today, or yesterday
  /// if today has no entry yet.
  final int streak;

  /// Whether today itself has an entry.
  final bool todayCounted;

  /// Days a saver was spent on in this evaluation (ascending).
  final List<DateTime> consumedDays;

  /// Previously saved days that now have an entry; their savers were
  /// returned, capped at [maxStreakSavers] (ascending).
  final List<DateTime> refundedDays;

  /// The input state with `savers`, `savedDays`, `lastMilestone` and
  /// `streakGoal` updated.
  final BuddyState next;

  /// Savers actually added to the stock by milestones in this evaluation
  /// (never more than the cap leaves room for).
  final int saversEarned;

  /// The new milestone (a multiple of [streakMilestoneDays]) when one was
  /// crossed in this evaluation, also when the stock was already full.
  /// `null` otherwise and always with `initialize`.
  final int? milestoneReached;

  /// The streak goal was reached; `next.streakGoal` is cleared.
  final bool goalReached;

  /// The gap ending yesterday could not be covered by savers and ended a run
  /// of at least 2 days. Stays `true` on every evaluation while the gap is
  /// open; use [brokenAfter] to announce each break once.
  final bool streakBroken;

  /// The last counted day before the unfillable gap when [streakBroken];
  /// identifies the break.
  final DateTime? brokenAfter;

  /// The streak reaches back to `windowStart` (`anchor - streak + 1 <=
  /// windowStart`), so it may be truncated. Break side effects are skipped;
  /// see [evaluateStreak].
  final bool reachesWindow;

  final BuddyState _previous;

  /// Whether [next] differs from the input state and needs to be saved.
  bool get changed => next != _previous;
}

/// Evaluates the streak for [today] from the local-midnight [activityDays]
/// (days with at least one entry) and the persisted [state].
///
/// 1. Saved days that now have an entry are refunded (stock capped at 2).
/// 2. A gap ending yesterday is filled with savers if the stock covers all of
///    it and the run before it is at least 2 days long; otherwise, after such
///    a run, the streak is reported broken.
/// 3. Saved days count toward the streak.
/// 4. Each newly reached 7-day milestone adds a saver (stock capped at 2).
///    After a break, `lastMilestone` is reset to the current run's milestone
///    (without reward) only once the break is final, i.e. yesterday is
///    counted again (a new run has started). Until then the user can still
///    repair the streak by backfilling yesterday, and a reset would pay the
///    old milestones a second time.
/// 5. A reached streak goal is cleared.
///
/// With [initialize] (a freshly created `buddy_state` row for an existing
/// user), `lastMilestone` is set to the current milestone without rewards.
///
/// Activity is assumed to be complete from [windowStart] on; the gap scan
/// stops there. If [StreakEvaluation.reachesWindow] is `true` the streak may
/// be truncated: the caller must fetch a larger window and call this again
/// with the **original input state** (never chain `next` of the truncated
/// result). Break side effects (milestone reset,
/// [StreakEvaluation.streakBroken]) are skipped while the window is reached.
///
/// All dates are treated as local calendar days; date arithmetic uses
/// calendar-day increments so DST switches never skip or double a day.
StreakEvaluation evaluateStreak({
  required Set<DateTime> activityDays,
  required BuddyState state,
  required DateTime today,
  required DateTime windowStart,
  bool initialize = false,
}) {
  final day0 = startOfDay(today);
  final window = startOfDay(windowStart);
  final yesterday = _addDays(day0, -1);
  final activity = activityDays.map(startOfDay).toSet();

  // 1. Refund saved days that have since been backfilled.
  final saved = <DateTime>{};
  final refunded = <DateTime>[];
  for (final day in state.savedDays.map(startOfDay).toSet()) {
    if (activity.contains(day)) {
      refunded.add(day);
    } else {
      saved.add(day);
    }
  }
  refunded.sort();
  var savers = math.min(maxStreakSavers, state.savers + refunded.length);

  // 2. A day counts if it has an entry or was saved.
  bool counted(DateTime day) => activity.contains(day) || saved.contains(day);

  // 3. Fill the gap ending yesterday with savers, if stock covers all of it
  //    and there is a run worth protecting before it.
  final consumed = <DateTime>[];
  DateTime? brokenAfter;
  if (!counted(yesterday)) {
    final gap = <DateTime>[];
    var cursor = yesterday;
    while (!cursor.isBefore(window) && !counted(cursor)) {
      gap.add(cursor);
      cursor = _addDays(cursor, -1);
    }
    // `cursor` is now the day immediately before the gap.
    if (gap.isNotEmpty && _runLength(cursor, counted) >= _minRunToProtect) {
      if (gap.length <= savers) {
        saved.addAll(gap);
        savers -= gap.length;
        consumed.addAll(gap.reversed);
      } else {
        brokenAfter = cursor;
      }
    }
  }

  // 4. Streak: walk back from today (or yesterday while today is open).
  final todayCounted = counted(day0);
  final anchor = todayCounted ? day0 : yesterday;
  final streak = _runLength(anchor, counted);
  final reachesWindow =
      streak > 0 && !_addDays(anchor, 1 - streak).isAfter(window);
  if (reachesWindow) brokenAfter = null;

  // 5. Milestones.
  final milestone = (streak ~/ streakMilestoneDays) * streakMilestoneDays;
  var lastMilestone = state.lastMilestone;
  var saversEarned = 0;
  int? milestoneReached;
  if (initialize) {
    lastMilestone = milestone;
  } else {
    final breakIsFinal =
        streak < lastMilestone && counted(yesterday) && !reachesWindow;
    if (breakIsFinal) {
      // The current run restarts the milestone count at its own milestone;
      // nothing is paid here, so shrinking a run (an entry deleted or moved)
      // never earns savers by itself.
      lastMilestone = milestone;
    } else if (milestone > lastMilestone) {
      final before = savers;
      savers = math.min(
        maxStreakSavers,
        savers + (milestone - lastMilestone) ~/ streakMilestoneDays,
      );
      saversEarned = savers - before;
      milestoneReached = milestone;
      lastMilestone = milestone;
    }
  }

  // 6. Goal.
  final goal = state.streakGoal;
  final goalReached = goal != null && streak >= goal;

  final savedDays = refunded.isEmpty && consumed.isEmpty
      ? state.savedDays
      : (saved.toList()..sort());

  return StreakEvaluation(
    streak: streak,
    todayCounted: todayCounted,
    consumedDays: List.unmodifiable(consumed),
    refundedDays: List.unmodifiable(refunded),
    next: state.copyWith(
      savers: savers,
      savedDays: savedDays,
      lastMilestone: lastMilestone,
      streakGoal: goalReached ? null : goal,
    ),
    saversEarned: saversEarned,
    milestoneReached: milestoneReached,
    goalReached: goalReached,
    streakBroken: brokenAfter != null,
    brokenAfter: brokenAfter,
    reachesWindow: reachesWindow,
    previous: state,
  );
}

/// Number of consecutive counted days walking back from [from].
int _runLength(DateTime from, bool Function(DateTime) counted) {
  var length = 0;
  for (var day = from; counted(day); day = _addDays(day, -1)) {
    length++;
  }
  return length;
}

/// Calendar-day arithmetic (never `Duration(hours: 24)`, which drifts across
/// DST switches).
DateTime _addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);
