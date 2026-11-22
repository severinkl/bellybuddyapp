import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/buddy_state.dart';
import '../repositories/buddy_repository.dart';
import '../repositories/entry_repository.dart';
import '../services/buddy/streak_engine.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';
import 'core_providers.dart';

/// The Buddy's clock. Day boundaries use its local date; tests override it.
final buddyTodayProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// One-shot Buddy messages. The dashboard plays them, then calls
/// [BuddyNotifier.clearAnnouncements]. Each one is produced at most once per
/// local day (`streakBroken`: once per break).
enum BuddyAnnouncement { saverUsed, streakBroken, saverEarned, goalReached }

/// The signed-in user's Buddy after today's streak evaluation.
class BuddyStatus {
  const BuddyStatus({
    required this.state,
    required this.hasRow,
    required this.streak,
    required this.todayCounted,
    this.announcements = const [],
  });

  /// Evaluated state; the defaults while [hasRow] is false.
  final BuddyState state;

  /// Whether a `buddy_state` row exists. Created by
  /// [BuddyNotifier.setName], [BuddyNotifier.setStreakGoal] or
  /// [BuddyNotifier.completeOnboarding].
  final bool hasRow;

  /// Current streak in days (counted or saved).
  final int streak;

  /// Whether today already has an entry.
  final bool todayCounted;

  /// Announcements not yet played, in the order they arose.
  final List<BuddyAnnouncement> announcements;

  BuddyStatus copyWith({List<BuddyAnnouncement>? announcements}) => BuddyStatus(
    state: state,
    hasRow: hasRow,
    streak: streak,
    todayCounted: todayCounted,
    announcements: announcements ?? this.announcements,
  );
}

/// Loads the Buddy, evaluates the streak (savers, refunds, milestones, goal),
/// persists the result and exposes it; `null` while signed out.
class BuddyNotifier extends AsyncNotifier<BuddyStatus?> {
  static const _log = AppLogger('BuddyProvider');

  /// Days of entry history fetched first; doubled while the streak reaches
  /// the window start, up to [_maxWindowDays].
  static const _initialWindowDays = 120;
  static const _maxWindowDays = 3650;

  /// Loads, refreshes and mutations run one after another, each on freshly
  /// fetched data, so a slow refresh never overwrites a newer write.
  /// Queued work never awaits [future] (that would deadlock behind a rebuild).
  Future<void> _tail = Future<void>.value();

  @override
  Future<BuddyStatus?> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return null;
    try {
      final status = await _serialized(() => _sync(userId));
      return _withPending(userId, status);
    } catch (e, st) {
      _log.error('Loading the Buddy failed', e, st);
      rethrow;
    }
  }

  /// Re-fetches the row and activity days, re-evaluates and persists changes
  /// (only when the row exists). On failure the last data is kept (an error
  /// state stays an error) and the error is rethrown.
  Future<void> refresh() {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return Future<void>.value();
    final opRef = ref;
    return _serialized(() async {
      try {
        _publish(opRef, userId, await _sync(userId));
      } catch (e, st) {
        _log.error('Refreshing the Buddy failed', e, st);
        if (_isCurrent(opRef, userId) && !state.hasValue) {
          state = AsyncError<BuddyStatus?>(e, st);
        }
        rethrow;
      }
    });
  }

  /// Renames the Buddy (trimmed, 1–20 characters) and creates the row if
  /// missing. Throws [ArgumentError] for an invalid name.
  Future<void> setName(String name) async {
    final trimmed = name.trim();
    final length = trimmed.runes.length;
    if (length < 1 || length > AppConstants.buddyNameMaxLength) {
      throw ArgumentError.value(
        name,
        'name',
        'Der Name muss 1 bis ${AppConstants.buddyNameMaxLength} Zeichen '
            'lang sein.',
      );
    }
    await _mutate('setName', (s) => s.copyWith(name: trimmed));
  }

  /// Sets or clears the streak goal; creates the row if missing.
  Future<void> setStreakGoal(int? goal) =>
      _mutate('setStreakGoal', (s) => s.copyWith(streakGoal: goal));

  /// Marks the Buddy onboarding as done and grants the gift saver (capped at
  /// [maxStreakSavers]). Idempotent: once `onboardingCompletedAt` is set,
  /// nothing changes. Creates the row if missing.
  Future<void> completeOnboarding({bool grantGiftSaver = true}) {
    final now = ref.read(buddyTodayProvider)();
    return _mutate('completeOnboarding', (s) {
      if (s.onboardingCompletedAt != null) return s;
      return s.copyWith(
        onboardingCompletedAt: now,
        savers: grantGiftSaver
            ? math.min(maxStreakSavers, s.savers + 1)
            : s.savers,
      );
    });
  }

  /// Drops the pending announcements once the UI has played them.
  void clearAnnouncements() {
    final current = state;
    final status = current.value;
    if (current.isLoading ||
        current.hasError ||
        status == null ||
        status.announcements.isEmpty) {
      return;
    }
    state = AsyncData(status.copyWith(announcements: const []));
  }

  Future<void> _mutate(
    String action,
    BuddyState Function(BuddyState current) change,
  ) {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      return Future<void>.error(StateError('$action: not signed in'));
    }
    final opRef = ref;
    return _serialized(() async {
      try {
        _publish(opRef, userId, await _sync(userId, change: change));
      } catch (e, st) {
        _log.error('$action failed', e, st);
        rethrow;
      }
    });
  }

  Future<T> _serialized<T>(Future<T> Function() op) {
    final result = _tail.then((_) => op());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Fetches the row and activity days, evaluates the streak and saves the
  /// result: evaluation changes only for an existing row; with [change] the
  /// changed state, creating the row (initialised at the current milestone,
  /// no rewards) when missing.
  Future<BuddyStatus> _sync(
    String userId, {
    BuddyState Function(BuddyState current)? change,
  }) async {
    final repo = ref.read(buddyRepositoryProvider);
    final entries = ref.read(entryRepositoryProvider);
    final today = startOfDay(ref.read(buddyTodayProvider)());
    final row = await repo.fetch(userId);
    final hasRow = row != null;
    final stored = (row ?? const BuddyState()).copyWith(userId: userId);

    final evaluation = await _evaluate(
      entries,
      userId,
      stored,
      today,
      initialize: !hasRow,
    );
    final next = change == null ? evaluation.next : change(evaluation.next);

    if (change != null) {
      if (!hasRow || next != stored) await repo.save(userId, next);
    } else if (hasRow && evaluation.changed) {
      try {
        await repo.save(userId, next);
      } catch (e, st) {
        // Non-fatal: the next evaluation recomputes from the stored row.
        _log.error('Saving the streak evaluation failed', e, st);
      }
    }

    return BuddyStatus(
      state: next,
      hasRow: hasRow || change != null,
      streak: evaluation.streak,
      todayCounted: evaluation.todayCounted,
      announcements: hasRow ? await _announce(evaluation, today) : const [],
    );
  }

  /// Evaluates [state] over a window of activity days that is doubled (always
  /// from the original [state]) while the streak reaches its start.
  Future<StreakEvaluation> _evaluate(
    EntryRepository entries,
    String userId,
    BuddyState state,
    DateTime today, {
    required bool initialize,
  }) async {
    var windowDays = _initialWindowDays;
    while (true) {
      final windowStart = DateTime(
        today.year,
        today.month,
        today.day - windowDays,
      );
      final days = await entries.fetchActivityDays(
        userId: userId,
        since: windowStart,
      );
      final evaluation = evaluateStreak(
        activityDays: days,
        state: state,
        today: today,
        windowStart: windowStart,
        initialize: initialize,
      );
      if (!evaluation.reachesWindow || windowDays >= _maxWindowDays) {
        return evaluation;
      }
      windowDays = math.min(windowDays * 2, _maxWindowDays);
    }
  }

  /// Announcements for [evaluation] that were not produced before (flags in
  /// SharedPreferences, one per kind and day; `streakBroken` per break).
  Future<List<BuddyAnnouncement>> _announce(
    StreakEvaluation evaluation,
    DateTime today,
  ) async {
    final candidates = <BuddyAnnouncement, DateTime>{
      if (evaluation.consumedDays.isNotEmpty)
        BuddyAnnouncement.saverUsed: today,
      BuddyAnnouncement.streakBroken: ?evaluation.brokenAfter,
      if (evaluation.saversEarned > 0) BuddyAnnouncement.saverEarned: today,
      if (evaluation.goalReached) BuddyAnnouncement.goalReached: today,
    };
    if (candidates.isEmpty) return const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final fresh = <BuddyAnnouncement>[];
      for (final MapEntry(key: kind, value: day) in candidates.entries) {
        final key =
            '${AppConstants.keyBuddyAnnouncedPrefix}${kind.name}_${_dayKey(day)}';
        if (prefs.getBool(key) ?? false) continue;
        await prefs.setBool(key, true);
        fresh.add(kind);
      }
      return fresh;
    } catch (e, st) {
      // Better to repeat a message than to lose a one-shot one.
      _log.error('Announcement flags unavailable', e, st);
      return candidates.keys.toList();
    }
  }

  /// Sets [fresh] as the state unless the user changed meanwhile.
  void _publish(Ref opRef, String userId, BuddyStatus fresh) {
    if (!_isCurrent(opRef, userId)) return;
    state = AsyncData(_withPending(userId, fresh));
  }

  /// Whether work started with [opRef] for [userId] may still set the state:
  /// no rebuild happened since ([opRef] is still mounted) and none is due.
  bool _isCurrent(Ref opRef, String userId) =>
      opRef.mounted && ref.read(currentUserIdProvider) == userId;

  /// [fresh] plus the not yet played announcements of the same user.
  BuddyStatus _withPending(String userId, BuddyStatus fresh) {
    final current = state.value;
    if (current == null ||
        current.state.userId != userId ||
        current.announcements.isEmpty) {
      return fresh;
    }
    final pending = current.announcements;
    return fresh.copyWith(
      announcements: [
        ...pending,
        ...fresh.announcements.where((a) => !pending.contains(a)),
      ],
    );
  }

  static String _dayKey(DateTime day) {
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '${day.year.toString().padLeft(4, '0')}-$m-$d';
  }
}

/// No automatic rebuild retries: the repository already retries the fetch,
/// and a missing table or offline backend should surface as an [AsyncError]
/// right away (the UI degrades); the next refresh recovers.
Duration? _noRetry(int retryCount, Object error) => null;

final buddyProvider = AsyncNotifierProvider<BuddyNotifier, BuddyStatus?>(
  BuddyNotifier.new,
  retry: _noRetry,
);
