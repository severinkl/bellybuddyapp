import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/services/buddy/streak_engine.dart';

DateTime nov(int day) => DateTime(2026, 11, day);

DateTime oct(int day) => DateTime(2026, 10, day);

DateTime mar(int day) => DateTime(2026, 3, day);

/// The caller's default window: 120 days before [today].
DateTime window120(DateTime today) =>
    DateTime(today.year, today.month, today.day - 120);

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
    this.windowStart,
    this.initialize = false,
    required this.streak,
    required this.todayCounted,
    this.consumed = const [],
    this.refunded = const [],
    this.saversEarned = 0,
    this.milestoneReached,
    this.goalReached = false,
    this.streakBroken = false,
    this.brokenAfter,
    this.reachesWindow = false,
    this.next,
  });

  final String description;
  final Set<DateTime> activity;
  final BuddyState state;

  /// Defaults to 22.11.2026.
  final DateTime? today;

  /// Defaults to 120 days before [today].
  final DateTime? windowStart;
  final bool initialize;

  final int streak;
  final bool todayCounted;
  final List<DateTime> consumed;
  final List<DateTime> refunded;
  final int saversEarned;
  final int? milestoneReached;
  final bool goalReached;
  final bool streakBroken;
  final DateTime? brokenAfter;
  final bool reachesWindow;

  /// Expected `next` state; `null` means "unchanged" (`changed == false`).
  final BuddyState? next;
}

StreakEvaluation _eval(
  Set<DateTime> activity,
  BuddyState state, {
  DateTime? today,
  DateTime? windowStart,
  bool initialize = false,
}) {
  final day = today ?? nov(22);
  return evaluateStreak(
    activityDays: activity,
    state: state,
    today: day,
    windowStart: windowStart ?? window120(day),
    initialize: initialize,
  );
}

void main() {
  final cases = <_Case>[
    // --- Basics ---
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
      'today not logged yet, yesterday counted → streak through yesterday',
      activity: span(nov(18), nov(21)),
      streak: 4,
      todayCounted: false,
    ),
    _Case(
      'today with a time of day is normalised to its date',
      activity: span(nov(20), nov(22)),
      today: DateTime(2026, 11, 22, 15, 30),
      streak: 3,
      todayCounted: true,
    ),

    // --- Savers fill the gap ending yesterday ---
    _Case(
      'yesterday missing, 5 days before, 1 saver → saver fills yesterday, '
      'streak 7 reaches milestone 7 → saver back to 1',
      activity: {...span(nov(16), nov(20)), nov(22)},
      state: const BuddyState(savers: 1),
      streak: 7,
      todayCounted: true,
      consumed: [nov(21)],
      saversEarned: 1,
      milestoneReached: 7,
      next: BuddyState(
        savers: 1,
        savedDays: [nov(21)],
        lastMilestone: 7,
        lastSaverEarnedOn: nov(22),
      ),
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
      'today and yesterday unlogged, 2 savers → only yesterday is filled',
      activity: span(nov(15), nov(20)),
      state: const BuddyState(savers: 2),
      streak: 7,
      todayCounted: false,
      consumed: [nov(21)],
      saversEarned: 1,
      milestoneReached: 7,
      next: BuddyState(
        savers: 2,
        savedDays: [nov(21)],
        lastMilestone: 7,
        lastSaverEarnedOn: nov(22),
      ),
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
      'old gap ending 3 days ago is never filled, even with savers',
      activity: {...span(nov(14), nov(18)), ...span(nov(20), nov(22))},
      state: const BuddyState(savers: 2),
      streak: 3,
      todayCounted: true,
    ),
    _Case(
      'gap after a 1-day run is not filled, even with savers',
      activity: {nov(20), nov(22)},
      state: const BuddyState(savers: 2),
      streak: 1,
      todayCounted: true,
    ),
    _Case(
      'gap after a 1-day run, today open → not filled, streak 0',
      activity: {nov(20)},
      state: const BuddyState(savers: 1),
      streak: 0,
      todayCounted: false,
    ),
    _Case(
      'gap after a 2-day run is filled',
      activity: {nov(19), nov(20), nov(22)},
      state: const BuddyState(savers: 1),
      streak: 4,
      todayCounted: true,
      consumed: [nov(21)],
      next: BuddyState(savedDays: [nov(21)]),
    ),

    // --- Broken streak ---
    _Case(
      'gap of 2 with 1 saver → not filled, streak broken, today only',
      activity: {...span(nov(15), nov(19)), nov(22)},
      state: const BuddyState(savers: 1),
      streak: 1,
      todayCounted: true,
      streakBroken: true,
      brokenAfter: nov(19),
    ),
    _Case(
      'gap after a single counted day → not reported as a broken streak',
      activity: {nov(19), nov(22)},
      streak: 1,
      todayCounted: true,
    ),

    // --- Refunds ---
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
      'duplicate saved days are deduped and refunded once',
      activity: span(nov(19), nov(22)),
      state: BuddyState(savedDays: [nov(10), nov(21), nov(21)]),
      streak: 4,
      todayCounted: true,
      refunded: [nov(21)],
      next: BuddyState(savers: 1, savedDays: [nov(10)]),
    ),
    _Case(
      'refund and consumption in one evaluation → refunded saver is reused',
      activity: span(nov(15), nov(20)),
      state: BuddyState(savedDays: [nov(20)], lastMilestone: 7),
      streak: 7,
      todayCounted: false,
      refunded: [nov(20)],
      consumed: [nov(21)],
      next: BuddyState(savedDays: [nov(21)], lastMilestone: 7),
    ),
    _Case(
      'refund at full stock is capped before the consumption',
      activity: span(nov(15), nov(20)),
      state: BuddyState(savers: 2, savedDays: [nov(20)], lastMilestone: 7),
      streak: 7,
      todayCounted: false,
      refunded: [nov(20)],
      consumed: [nov(21)],
      next: BuddyState(savers: 1, savedDays: [nov(21)], lastMilestone: 7),
    ),
    _Case(
      'saved days count toward the streak',
      activity: {...span(nov(15), nov(20)), nov(22)},
      state: BuddyState(savedDays: [nov(21)], lastMilestone: 7),
      streak: 8,
      todayCounted: true,
    ),
    _Case(
      'saved day older than the window is kept and never refunded',
      activity: span(nov(20), nov(22)),
      state: BuddyState(savedDays: [DateTime(2026, 7, 1)]),
      streak: 3,
      todayCounted: true,
    ),

    // --- Pruning (the backend caps saved_days at 400) ---
    _Case(
      'saved day more than 365 days ago, outside the current run → dropped',
      activity: span(nov(20), nov(22)),
      state: BuddyState(savedDays: [DateTime(2025, 11, 1), nov(10)]),
      streak: 3,
      todayCounted: true,
      next: BuddyState(savedDays: [nov(10)]),
    ),
    _Case(
      'saved day 366 days ago → dropped',
      activity: span(nov(20), nov(22)),
      state: BuddyState(savedDays: [DateTime(2025, 11, 21)]),
      streak: 3,
      todayCounted: true,
      next: const BuddyState(),
    ),
    _Case(
      'saved day exactly 365 days ago → kept',
      activity: span(nov(20), nov(22)),
      state: BuddyState(savedDays: [DateTime(2025, 11, 22)]),
      streak: 3,
      todayCounted: true,
    ),
    _Case(
      'old saved day dropped while a gap is filled → only the new one kept',
      activity: {...span(nov(16), nov(20)), nov(22)},
      state: BuddyState(
        savers: 1,
        savedDays: [DateTime(2025, 1, 5)],
        lastMilestone: 7,
      ),
      streak: 7,
      todayCounted: true,
      consumed: [nov(21)],
      next: BuddyState(savedDays: [nov(21)], lastMilestone: 7),
    ),

    // --- Milestones ---
    _Case(
      '10 consecutive days incl. today → milestone 7 earns a saver',
      activity: span(nov(13), nov(22)),
      streak: 10,
      todayCounted: true,
      saversEarned: 1,
      milestoneReached: 7,
      next: BuddyState(savers: 1, lastMilestone: 7, lastSaverEarnedOn: nov(22)),
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
      'two milestones at once with 1 saver → only 1 actually added (cap 2)',
      activity: span(nov(8), nov(22)),
      state: const BuddyState(savers: 1),
      streak: 15,
      todayCounted: true,
      saversEarned: 1,
      milestoneReached: 14,
      next: BuddyState(
        savers: 2,
        lastMilestone: 14,
        lastSaverEarnedOn: nov(22),
      ),
    ),
    _Case(
      'two milestones at once with an empty stock → still only 1 saver '
      '(one per evaluation)',
      activity: span(nov(8), nov(22)),
      streak: 15,
      todayCounted: true,
      saversEarned: 1,
      milestoneReached: 14,
      next: BuddyState(
        savers: 1,
        lastMilestone: 14,
        lastSaverEarnedOn: nov(22),
      ),
    ),
    _Case(
      'milestone less than 7 days after the last earned saver → '
      'milestoneReached, nothing paid',
      activity: span(nov(16), nov(22)),
      state: BuddyState(lastSaverEarnedOn: nov(16)),
      streak: 7,
      todayCounted: true,
      milestoneReached: 7,
      next: BuddyState(lastMilestone: 7, lastSaverEarnedOn: nov(16)),
    ),
    _Case(
      'milestone exactly 7 days after the last earned saver → paid',
      activity: span(nov(16), nov(22)),
      state: BuddyState(lastSaverEarnedOn: nov(15)),
      streak: 7,
      todayCounted: true,
      saversEarned: 1,
      milestoneReached: 7,
      next: BuddyState(savers: 1, lastMilestone: 7, lastSaverEarnedOn: nov(22)),
    ),
    _Case(
      'milestone at full stock → milestoneReached, 0 savers earned',
      activity: span(nov(16), nov(22)),
      state: const BuddyState(savers: 2),
      streak: 7,
      todayCounted: true,
      milestoneReached: 7,
      next: const BuddyState(savers: 2, lastMilestone: 7),
    ),
    _Case(
      'break while yesterday is still open → lastMilestone kept',
      activity: {...span(nov(1), nov(19)), nov(22)},
      state: const BuddyState(lastMilestone: 14),
      streak: 1,
      todayCounted: true,
      streakBroken: true,
      brokenAfter: nov(19),
    ),
    _Case(
      'break is final (yesterday counted) → lastMilestone resets',
      activity: {...span(nov(1), nov(19)), ...span(nov(21), nov(22))},
      state: const BuddyState(lastMilestone: 14),
      streak: 2,
      todayCounted: true,
      next: const BuddyState(),
    ),
    _Case(
      'final break found after the new run passed 7 → lastMilestone set to '
      '7, nothing paid',
      activity: {...span(oct(10), nov(10)), ...span(nov(12), nov(22))},
      state: const BuddyState(lastMilestone: 28),
      streak: 11,
      todayCounted: true,
      next: const BuddyState(lastMilestone: 7),
    ),

    // --- Goal ---
    _Case(
      'goal 7 reached → goalReached, goal cleared',
      activity: span(nov(16), nov(22)),
      state: const BuddyState(streakGoal: 7),
      streak: 7,
      todayCounted: true,
      saversEarned: 1,
      milestoneReached: 7,
      goalReached: true,
      next: BuddyState(savers: 1, lastMilestone: 7, lastSaverEarnedOn: nov(22)),
    ),
    _Case(
      'goal 14 not reached yet → goal kept',
      activity: span(nov(16), nov(22)),
      state: const BuddyState(streakGoal: 14),
      streak: 7,
      todayCounted: true,
      saversEarned: 1,
      milestoneReached: 7,
      next: BuddyState(
        streakGoal: 14,
        savers: 1,
        lastMilestone: 7,
        lastSaverEarnedOn: nov(22),
      ),
    ),

    // --- Window ---
    _Case(
      'streak starts the day after windowStart → reachesWindow false',
      activity: span(nov(19), nov(22)),
      windowStart: nov(18),
      streak: 4,
      todayCounted: true,
    ),
    _Case(
      'streak starts exactly at windowStart → reachesWindow true',
      activity: span(nov(18), nov(22)),
      windowStart: nov(18),
      streak: 5,
      todayCounted: true,
      reachesWindow: true,
    ),
    _Case(
      'streak anchored at yesterday reaching windowStart → reachesWindow true',
      activity: span(nov(18), nov(21)),
      windowStart: nov(18),
      streak: 4,
      todayCounted: false,
      reachesWindow: true,
    ),
    _Case(
      'streak walk continues past windowStart',
      activity: span(nov(14), nov(22)),
      state: const BuddyState(lastMilestone: 7),
      windowStart: nov(18),
      streak: 9,
      todayCounted: true,
      reachesWindow: true,
    ),
    _Case(
      'saved day before windowStart still counts in the walk',
      activity: {...span(nov(14), nov(16)), ...span(nov(18), nov(22))},
      state: BuddyState(savedDays: [nov(17)], lastMilestone: 7),
      windowStart: nov(18),
      streak: 9,
      todayCounted: true,
      reachesWindow: true,
    ),
    _Case(
      'truncated streak below lastMilestone → no reset while reachesWindow',
      activity: span(window120(nov(22)), nov(22)),
      state: const BuddyState(lastMilestone: 196),
      streak: 121,
      todayCounted: true,
      reachesWindow: true,
    ),

    // --- Day boundaries ---
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
        final result = _eval(
          c.activity,
          c.state,
          today: c.today,
          windowStart: c.windowStart,
          initialize: c.initialize,
        );
        final expectedNext = c.next ?? c.state;

        expect(result.streak, c.streak, reason: 'streak');
        expect(result.todayCounted, c.todayCounted, reason: 'todayCounted');
        expect(result.consumedDays, c.consumed, reason: 'consumedDays');
        expect(result.refundedDays, c.refunded, reason: 'refundedDays');
        expect(result.saversEarned, c.saversEarned, reason: 'saversEarned');
        expect(
          result.milestoneReached,
          c.milestoneReached,
          reason: 'milestoneReached',
        );
        expect(result.goalReached, c.goalReached, reason: 'goalReached');
        expect(result.streakBroken, c.streakBroken, reason: 'streakBroken');
        expect(result.brokenAfter, c.brokenAfter, reason: 'brokenAfter');
        expect(result.reachesWindow, c.reachesWindow, reason: 'reachesWindow');
        expect(result.next, expectedNext, reason: 'next');
        expect(result.changed, expectedNext != c.state, reason: 'changed');
      });
    }
  });

  group('evaluateStreak sequences', () {
    test('a backfilled saved day is refunded exactly once', () {
      final activity = span(nov(20), nov(22));
      final first = _eval(
        activity,
        BuddyState(savers: 1, savedDays: [nov(21)]),
      );
      final second = _eval(activity, first.next);

      expect(first.refundedDays, [nov(21)]);
      expect(first.next.savers, 2);
      expect(second.refundedDays, isEmpty);
      expect(second.next.savers, 2);
      expect(second.changed, isFalse);
    });

    test('the same saved gap is not consumed twice', () {
      final activity = {...span(nov(16), nov(20)), nov(22)};
      final first = _eval(
        activity,
        const BuddyState(savers: 2, lastMilestone: 7),
      );
      final second = _eval(activity, first.next);

      expect(first.consumedDays, [nov(21)]);
      expect(first.next.savers, 1);
      expect(second.consumedDays, isEmpty);
      expect(second.streak, 7);
      expect(second.changed, isFalse);
    });

    test('morning check, then backfilling yesterday → no phantom savers', () {
      // 16-day run through 20.11., 21.11. not logged yet, no savers.
      final morning = _eval(
        span(nov(5), nov(20)),
        const BuddyState(lastMilestone: 14),
      );
      expect(morning.streakBroken, isTrue);
      expect(morning.brokenAfter, nov(20));
      expect(morning.next.lastMilestone, 14);
      expect(morning.changed, isFalse);

      final backfilled = span(nov(5), nov(21));
      final afterBackfill = _eval(backfilled, morning.next);
      expect(afterBackfill.streak, 17);
      expect(afterBackfill.streakBroken, isFalse);
      expect(afterBackfill.saversEarned, 0);
      expect(afterBackfill.milestoneReached, isNull);
      expect(afterBackfill.next.savers, 0);
      expect(afterBackfill.next.lastMilestone, 14);

      final again = _eval(backfilled, afterBackfill.next);
      expect(again.changed, isFalse);
    });

    test('re-climb after a final break earns milestone 7 again', () {
      final oldRun = span(nov(1), nov(14)); // 15.11. missed
      var state = const BuddyState(lastMilestone: 14);

      // 16.11.: yesterday open → break not final yet.
      final day16 = _eval({...oldRun, nov(16)}, state, today: nov(16));
      expect(day16.streakBroken, isTrue);
      expect(day16.next.lastMilestone, 14);
      state = day16.next;

      // 17.11.: yesterday counted → break final, milestone resets.
      final day17 = _eval(
        {...oldRun, ...span(nov(16), nov(17))},
        state,
        today: nov(17),
      );
      expect(day17.next.lastMilestone, 0);
      state = day17.next;

      // 22.11.: new run 16.–22. reaches 7.
      final day22 = _eval({...oldRun, ...span(nov(16), nov(22))}, state);
      expect(day22.streak, 7);
      expect(day22.saversEarned, 1);
      expect(day22.milestoneReached, 7);
      expect(day22.next.savers, 1);
      expect(day22.next.lastMilestone, 7);
    });

    test('deleting and re-adding a mid-run day pays at most the re-crossed '
        'milestone', () {
      // Run 8.–22.11. (15 days); milestones 7 and 14 already paid.
      const paid = BuddyState(lastMilestone: 14);
      final full = span(nov(8), nov(22));

      // 14.11. loses its only entry → current run 15.–22. (8 days), final.
      final deleted = _eval(full.difference({nov(14)}), paid);
      expect(deleted.streak, 8);
      expect(deleted.saversEarned, 0);
      expect(deleted.milestoneReached, isNull);
      expect(deleted.next.savers, 0);
      expect(deleted.next.lastMilestone, 7);

      // Entry re-added → streak 15 crosses 14 again relative to 7.
      final readded = _eval(full, deleted.next);
      expect(readded.streak, 15);
      expect(readded.saversEarned, 1);
      expect(readded.milestoneReached, 14);
      expect(readded.next.savers, 1);
      expect(readded.next.lastMilestone, 14);

      final again = _eval(full, readded.next);
      expect(again.changed, isFalse);
    });

    test('deleting and re-adding a mid-run day right after a saver was '
        'earned pays nothing', () {
      // Run 9.–22.11. (14 days); milestone 14 paid today.
      final paid = BuddyState(
        savers: 1,
        lastMilestone: 14,
        lastSaverEarnedOn: nov(22),
      );
      final full = span(nov(9), nov(22));

      // 17.11. loses its only entry → current run 18.–22. (5 days), final.
      final deleted = _eval(full.difference({nov(17)}), paid);
      expect(deleted.streak, 5);
      expect(deleted.saversEarned, 0);
      expect(deleted.next.lastMilestone, 0);
      expect(deleted.next.savers, 1);

      // Entry re-added → milestone 14 crossed again, but within 7 days of
      // the last earned saver: recorded, not paid.
      final readded = _eval(full, deleted.next);
      expect(readded.streak, 14);
      expect(readded.saversEarned, 0);
      expect(readded.milestoneReached, 14);
      expect(readded.next.savers, 1);
      expect(readded.next.lastMilestone, 14);
      expect(readded.next.lastSaverEarnedOn, nov(22));

      // Toggling a day again on the following days still pays nothing.
      var state = readded.next;
      for (var day = 23; day <= 28; day++) {
        final run = span(nov(9), nov(day));
        final cut = _eval(
          run.difference({nov(day - 5)}),
          state,
          today: nov(day),
        );
        final back = _eval(run, cut.next, today: nov(day));
        expect(back.saversEarned, 0, reason: '$day.11.');
        expect(back.next.savers, 1, reason: '$day.11.');
        state = back.next;
      }

      final again = _eval(full, readded.next);
      expect(again.changed, isFalse);
    });

    test('a new run after a real break earns milestone 7 a week after the '
        'last saver', () {
      final oldRun = span(nov(1), nov(14)); // 15.11. missed
      // Milestone 14 was paid on 14.11.
      var state = BuddyState(
        savers: 1,
        lastMilestone: 14,
        lastSaverEarnedOn: nov(14),
      );

      final day17 = _eval(
        {...oldRun, ...span(nov(16), nov(17))},
        state,
        today: nov(17),
      );
      expect(day17.next.lastMilestone, 0);
      state = day17.next;

      final day22 = _eval({...oldRun, ...span(nov(16), nov(22))}, state);
      expect(day22.streak, 7);
      expect(day22.saversEarned, 1);
      expect(day22.next.savers, 2);
      expect(day22.next.lastMilestone, 7);
      expect(day22.next.lastSaverEarnedOn, nov(22));
    });

    test('initialize never pays and leaves lastSaverEarnedOn unset', () {
      final result = _eval(
        span(oct(14), nov(22)),
        const BuddyState(),
        initialize: true,
      );
      expect(result.saversEarned, 0);
      expect(result.next.savers, 0);
      expect(result.next.lastSaverEarnedOn, isNull);
      expect(result.next.lastMilestone, 35);
    });

    test('a saved day older than a year inside the current run is kept', () {
      // Run since 1.10.2025 with 1.11.2025 saved: longer than a year.
      final saved = DateTime(2025, 11, 1);
      final run = span(DateTime(2025, 10, 1), nov(22));
      final state = BuddyState(savedDays: [saved], lastMilestone: 413);

      final result = _eval(
        run.difference({saved}),
        state,
        windowStart: DateTime(2025, 6, 1),
      );

      expect(result.reachesWindow, isFalse);
      expect(result.streak, run.length);
      expect(result.next.savedDays, [saved]);
      expect(result.changed, isFalse);
    });

    test('nothing is pruned while the streak reaches the window', () {
      final saved = DateTime(2025, 11, 1);
      final run = span(DateTime(2025, 10, 1), nov(22));
      final state = BuddyState(savedDays: [saved], lastMilestone: 413);

      // The default 120-day window truncates the run.
      final truncated = _eval(
        run
            .difference({saved})
            .where((d) => !d.isBefore(window120(nov(22))))
            .toSet(),
        state,
      );

      expect(truncated.reachesWindow, isTrue);
      expect(truncated.next.savedDays, [saved]);
    });

    test('reachesWindow → re-evaluating the ORIGINAL state with a larger '
        'window gives the full streak', () {
      final today = nov(22);
      final fullHistory = span(DateTime(2026, 11, 22 - 199), today);
      const original = BuddyState();

      final narrow = window120(today);
      final truncated = _eval(
        fullHistory.where((d) => !d.isBefore(narrow)).toSet(),
        original,
        windowStart: narrow,
        initialize: true,
      );
      expect(truncated.reachesWindow, isTrue);
      expect(truncated.streak, 121);

      final full = _eval(
        fullHistory,
        original,
        windowStart: DateTime(2026, 11, 22 - 240),
        initialize: true,
      );
      expect(full.reachesWindow, isFalse);
      expect(full.streak, 200);
      expect(full.next.lastMilestone, 196);
      expect(full.saversEarned, 0);
    });
  });
}
