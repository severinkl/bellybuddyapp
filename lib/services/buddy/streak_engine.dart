import 'dart:math' as math;

import '../../models/buddy_state.dart';
import '../../utils/date_format_utils.dart';

/// Maximum number of streak savers a user can hold.
const int maxStreakSavers = 2;

/// Every multiple of this many streak days is a milestone worth one saver.
const int streakMilestoneDays = 7;

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
    required BuddyState previous,
  }) : _previous = previous;

  /// Consecutive counted days (activity or saved) ending today, or yesterday
  /// if today has no entry yet.
  final int streak;

  /// Whether today itself has an entry.
  final bool todayCounted;

  /// Days a saver was spent on in this evaluation (ascending).
  final List<DateTime> consumedDays;

  /// Previously saved days that now have an entry; their savers were
  /// returned (ascending).
  final List<DateTime> refundedDays;

  /// The input state with `savers`, `savedDays`, `lastMilestone` and
  /// `streakGoal` updated.
  final BuddyState next;

  /// Savers earned by newly reached 7-day milestones (before the stock cap).
  final int saversEarned;

  /// The streak goal was reached; `next.streakGoal` is cleared.
  final bool goalReached;

  /// The gap ending yesterday could not be covered by savers and ended a
  /// streak of at least 2 days.
  final bool streakBroken;

  final BuddyState _previous;

  /// Whether [next] differs from the input state and needs to be saved.
  bool get changed => next != _previous;
}

/// Evaluates the streak for [today] from the local-midnight [activityDays]
/// (days with at least one entry) and the persisted [state].
///
/// Applies refunds for backfilled saved days, auto-applies savers to a gap
/// ending yesterday, rewards 7-day milestones and checks the streak goal.
/// Saved days count toward the streak. The gap scan does not go back past
/// [windowStart]; if the returned streak reaches it, the caller re-evaluates
/// with a larger window.
///
/// With [initialize] (a freshly created `buddy_state` row for an existing
/// user), `lastMilestone` is set to the current milestone without rewards.
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

  // 3. Fill the gap ending yesterday with savers, if stock covers all of it.
  final consumed = <DateTime>[];
  var streakBroken = false;
  if (!counted(yesterday)) {
    final gap = <DateTime>[];
    var cursor = yesterday;
    while (!cursor.isBefore(window) && !counted(cursor)) {
      gap.add(cursor);
      cursor = _addDays(cursor, -1);
    }
    // `cursor` is now the day immediately before the gap.
    final countedBefore = gap.isNotEmpty && counted(cursor);
    if (countedBefore && gap.length <= savers) {
      saved.addAll(gap);
      savers -= gap.length;
      consumed.addAll(gap.reversed);
    } else if (countedBefore && counted(_addDays(cursor, -1))) {
      streakBroken = true;
    }
  }

  // 4. Streak: walk back from today (or yesterday while today is open).
  final todayCounted = counted(day0);
  var streak = 0;
  for (
    var day = todayCounted ? day0 : yesterday;
    counted(day);
    day = _addDays(day, -1)
  ) {
    streak++;
  }

  // 5. Milestones.
  final milestone = (streak ~/ streakMilestoneDays) * streakMilestoneDays;
  var lastMilestone = state.lastMilestone;
  var saversEarned = 0;
  if (initialize) {
    lastMilestone = milestone;
  } else if (milestone > lastMilestone) {
    saversEarned = (milestone - lastMilestone) ~/ streakMilestoneDays;
    savers = math.min(maxStreakSavers, savers + saversEarned);
    lastMilestone = milestone;
  } else if (streak < lastMilestone) {
    lastMilestone = milestone;
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
    goalReached: goalReached,
    streakBroken: streakBroken,
    previous: state,
  );
}

/// Calendar-day arithmetic (never `Duration(hours: 24)`, which drifts across
/// DST switches).
DateTime _addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);
