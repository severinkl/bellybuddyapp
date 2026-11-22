import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/services/buddy/streak_engine.dart';

DateTime nov(int day) => DateTime(2026, 11, day);

DateTime oct(int day) => DateTime(2026, 10, day);

DateTime mar(int day) => DateTime(2026, 3, day);

/// Inclusive run of local-midnight days, built by calendar-day increments.
Set<DateTime> span(DateTime from, DateTime to) {
  final days = <DateTime>{};
  for (var d = from; !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) {
    days.add(d);
  }
  return days;
}

/// Task 3's mapping (`EntryRepository.fetchActivityDays`): a `tracked_at`
/// instant becomes the local calendar day it falls on.
DateTime localDay(DateTime trackedAt) {
  final local = trackedAt.toLocal();
  return DateTime(local.year, local.month, local.day);
}

class _Case {
  _Case(
    this.description, {
    required this.activity,
    this.state = const BuddyState(),
    this.today,
    this.initialize = false,
    required this.streak,
    required this.todayCounted,
    this.consumed = const [],
    this.refunded = const [],
    this.saversEarned = 0,
    this.goalReached = false,
    this.streakBroken = false,
    this.next,
  });

  final String description;
  final Set<DateTime> activity;
  final BuddyState state;

  /// Defaults to 22.11.2026.
  final DateTime? today;
  final bool initialize;

  final int streak;
  final bool todayCounted;
  final List<DateTime> consumed;
  final List<DateTime> refunded;
  final int saversEarned;
  final bool goalReached;
  final bool streakBroken;

  /// Expected `next` state; `null` means "unchanged" (`changed == false`).
  final BuddyState? next;
}

void main() {
  final cases = <_Case>[
    _Case(
      'no activity → streak 0, nothing consumed',
      activity: {},
      streak: 0,
      todayCounted: false,
    ),
    _Case(
      'no activity with savers in stock → savers untouched',
      activity: {},
      state: const BuddyState(savers: 2),
      streak: 0,
      todayCounted: false,
    ),
    _Case(
      'today only → streak 1',
      activity: {nov(22)},
      state: const BuddyState(savers: 2),
      streak: 1,
      todayCounted: true,
    ),
    _Case(
      '10 consecutive days incl. today → milestone 7 earns a saver',
      activity: span(nov(13), nov(22)),
      streak: 10,
      todayCounted: true,
      saversEarned: 1,
      next: const BuddyState(savers: 1, lastMilestone: 7),
    ),
    _Case(
      'yesterday missing, 5 days before, 1 saver → saver fills yesterday, '
      'streak 7 reaches milestone 7 → saver back to 1',
      activity: {...span(nov(16), nov(20)), nov(22)},
      state: const BuddyState(savers: 1),
      streak: 7,
      todayCounted: true,
      consumed: [nov(21)],
      saversEarned: 1,
      next: BuddyState(savers: 1, savedDays: [nov(21)], lastMilestone: 7),
    ),
    _Case(
      'yesterday missing, today not logged yet → saver fills yesterday, '
      'streak runs through the saved day',
      activity: span(nov(16), nov(20)),
      state: const BuddyState(savers: 1),
      streak: 6,
      todayCounted: false,
      consumed: [nov(21)],
      next: BuddyState(savedDays: [nov(21)]),
    ),
    _Case(
      'gap of 2 with 2 savers → both days filled, savedDays ascending',
      activity: {...span(nov(15), nov(19)), nov(22)},
      state: const BuddyState(savers: 2, lastMilestone: 7),
      streak: 8,
      todayCounted: true,
      consumed: [nov(20), nov(21)],
      next: BuddyState(savedDays: [nov(20), nov(21)], lastMilestone: 7),
    ),
    _Case(
      'filling a gap merges with older saved days in ascending order',
      activity: {...span(nov(14), nov(16)), ...span(nov(18), nov(20)), nov(22)},
      state: BuddyState(savers: 1, savedDays: [nov(17)], lastMilestone: 7),
      streak: 9,
      todayCounted: true,
      consumed: [nov(21)],
      next: BuddyState(savedDays: [nov(17), nov(21)], lastMilestone: 7),
    ),
    _Case(
      'gap of 2 with 1 saver → not filled, streak broken, today only',
      activity: {...span(nov(15), nov(19)), nov(22)},
      state: const BuddyState(savers: 1),
      streak: 1,
      todayCounted: true,
      streakBroken: true,
    ),
    _Case(
      'gap after a single counted day → not reported as a broken streak',
      activity: {nov(19), nov(22)},
      streak: 1,
      todayCounted: true,
    ),
    _Case(
      'refund: backfilled saved day returns the saver',
      activity: span(nov(20), nov(22)),
      state: BuddyState(savedDays: [nov(21)]),
      streak: 3,
      todayCounted: true,
      refunded: [nov(21)],
      next: const BuddyState(savers: 1),
    ),
    _Case(
      'refund with 1 saver in stock → 2',
      activity: span(nov(20), nov(22)),
      state: BuddyState(savers: 1, savedDays: [nov(21)]),
      streak: 3,
      todayCounted: true,
      refunded: [nov(21)],
      next: const BuddyState(savers: 2),
    ),
    _Case(
      'refund with 2 savers in stock → stays capped at 2',
      activity: span(nov(20), nov(22)),
      state: BuddyState(savers: 2, savedDays: [nov(21)]),
      streak: 3,
      todayCounted: true,
      refunded: [nov(21)],
      next: const BuddyState(savers: 2),
    ),
    _Case(
      'refund only touches backfilled days, other saved days stay',
      activity: {...span(nov(17), nov(19)), ...span(nov(21), nov(22))},
      state: BuddyState(savedDays: [nov(18), nov(20)]),
      streak: 6,
      todayCounted: true,
      refunded: [nov(18)],
      next: BuddyState(savers: 1, savedDays: [nov(20)]),
    ),
    _Case(
      'saved days count toward the streak',
      activity: {...span(nov(15), nov(20)), nov(22)},
      state: BuddyState(savedDays: [nov(21)], lastMilestone: 7),
      streak: 8,
      todayCounted: true,
    ),
    _Case(
      'initialize with a 40-day streak → lastMilestone 35, no rewards',
      activity: span(oct(14), nov(22)),
      initialize: true,
      streak: 40,
      todayCounted: true,
      next: const BuddyState(lastMilestone: 35),
    ),
    _Case(
      'already rewarded milestone → no second reward',
      activity: span(nov(13), nov(22)),
      state: const BuddyState(lastMilestone: 7),
      streak: 10,
      todayCounted: true,
    ),
    _Case(
      'two milestones at once → 2 earned, stock capped at 2',
      activity: span(nov(8), nov(22)),
      state: const BuddyState(savers: 1),
      streak: 15,
      todayCounted: true,
      saversEarned: 2,
      next: const BuddyState(savers: 2, lastMilestone: 14),
    ),
    _Case(
      'streak below lastMilestone after a break → milestone resets',
      activity: {...span(nov(1), nov(19)), nov(22)},
      state: const BuddyState(lastMilestone: 14),
      streak: 1,
      todayCounted: true,
      streakBroken: true,
      next: const BuddyState(),
    ),
    _Case(
      'goal 7 reached → goalReached, goal cleared',
      activity: span(nov(16), nov(22)),
      state: const BuddyState(streakGoal: 7),
      streak: 7,
      todayCounted: true,
      saversEarned: 1,
      goalReached: true,
      next: const BuddyState(savers: 1, lastMilestone: 7),
    ),
    _Case(
      'goal 14 not reached yet → goal kept',
      activity: span(nov(16), nov(22)),
      state: const BuddyState(streakGoal: 14),
      streak: 7,
      todayCounted: true,
      saversEarned: 1,
      next: const BuddyState(streakGoal: 14, savers: 1, lastMilestone: 7),
    ),
    _Case(
      'today not logged yet, yesterday counted → streak through yesterday',
      activity: span(nov(18), nov(21)),
      streak: 4,
      todayCounted: false,
    ),
    _Case(
      'old gap ending 3 days ago is never filled, even with savers',
      activity: {...span(nov(14), nov(18)), ...span(nov(20), nov(22))},
      state: const BuddyState(savers: 2),
      streak: 3,
      todayCounted: true,
    ),
    _Case(
      'midnight: 23:59 and 00:01 local count as two days',
      activity: {
        localDay(DateTime(2026, 11, 21, 23, 59).toUtc()),
        localDay(DateTime(2026, 11, 22, 0, 1).toUtc()),
      },
      streak: 2,
      todayCounted: true,
    ),
    _Case(
      'today with a time of day is normalised to its date',
      activity: span(nov(20), nov(22)),
      today: DateTime(2026, 11, 22, 15, 30),
      streak: 3,
      todayCounted: true,
    ),
    _Case(
      'DST spring forward (29.03.2026): 3-day run around it counts 3',
      activity: span(mar(28), mar(30)),
      today: mar(30),
      streak: 3,
      todayCounted: true,
    ),
    _Case(
      'DST fall back (25.10.2026): 3-day run around it counts 3',
      activity: span(oct(24), oct(26)),
      today: oct(26),
      streak: 3,
      todayCounted: true,
    ),
    _Case(
      'DST spring forward: a saver fills the switch day',
      activity: {...span(mar(25), mar(28)), mar(30)},
      today: mar(30),
      state: const BuddyState(savers: 1),
      streak: 6,
      todayCounted: true,
      consumed: [mar(29)],
      next: BuddyState(savedDays: [mar(29)]),
    ),
  ];

  group('evaluateStreak', () {
    for (final c in cases) {
      test(c.description, () {
        final today = c.today ?? nov(22);
        final result = evaluateStreak(
          activityDays: c.activity,
          state: c.state,
          today: today,
          windowStart: DateTime(today.year, today.month, today.day - 120),
          initialize: c.initialize,
        );
        final expectedNext = c.next ?? c.state;

        expect(result.streak, c.streak, reason: 'streak');
        expect(result.todayCounted, c.todayCounted, reason: 'todayCounted');
        expect(result.consumedDays, c.consumed, reason: 'consumedDays');
        expect(result.refundedDays, c.refunded, reason: 'refundedDays');
        expect(result.saversEarned, c.saversEarned, reason: 'saversEarned');
        expect(result.goalReached, c.goalReached, reason: 'goalReached');
        expect(result.streakBroken, c.streakBroken, reason: 'streakBroken');
        expect(result.next, expectedNext, reason: 'next');
        expect(result.changed, expectedNext != c.state, reason: 'changed');
      });
    }

    test('a backfilled saved day is refunded exactly once', () {
      final activity = span(nov(20), nov(22));
      final first = evaluateStreak(
        activityDays: activity,
        state: BuddyState(savers: 1, savedDays: [nov(21)]),
        today: nov(22),
        windowStart: DateTime(2026, 11, 22 - 120),
      );
      final second = evaluateStreak(
        activityDays: activity,
        state: first.next,
        today: nov(22),
        windowStart: DateTime(2026, 11, 22 - 120),
      );

      expect(first.refundedDays, [nov(21)]);
      expect(first.next.savers, 2);
      expect(second.refundedDays, isEmpty);
      expect(second.next.savers, 2);
      expect(second.changed, isFalse);
    });

    test('the same saved gap is not consumed twice', () {
      final activity = {...span(nov(16), nov(20)), nov(22)};
      final first = evaluateStreak(
        activityDays: activity,
        state: const BuddyState(savers: 2, lastMilestone: 7),
        today: nov(22),
        windowStart: DateTime(2026, 11, 22 - 120),
      );
      final second = evaluateStreak(
        activityDays: activity,
        state: first.next,
        today: nov(22),
        windowStart: DateTime(2026, 11, 22 - 120),
      );

      expect(first.consumedDays, [nov(21)]);
      expect(first.next.savers, 1);
      expect(second.consumedDays, isEmpty);
      expect(second.streak, 7);
      expect(second.changed, isFalse);
    });
  });
}
