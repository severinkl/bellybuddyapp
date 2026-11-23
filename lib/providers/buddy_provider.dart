import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/buddy_state.dart';
import '../repositories/auth_repository.dart';
import '../repositories/buddy_repository.dart';
import '../repositories/entry_repository.dart';
import '../services/buddy/streak_engine.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';
import 'core_providers.dart';

/// The Buddy's clock. Day boundaries use its local date; tests override it.
final buddyTodayProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// One-shot Buddy messages. They stay pending across refreshes until the
/// dashboard has played them and calls
/// [BuddyNotifier.markAnnouncementsShown], which sets their flags; each one
/// is shown at most once per user and local day (`streakBroken`: once per
/// break, `goalReached`: once per goal). Pending ones live in memory only:
/// after a restart, `streakBroken` and `goalReached` come again while their
/// cause still holds, but `saverUsed` and `saverEarned` (produced only by
/// the evaluation that saved the change) are gone.
enum BuddyAnnouncement { saverUsed, streakBroken, saverEarned, goalReached }

/// The signed-in user's Buddy after today's streak evaluation.
class BuddyStatus {
  const BuddyStatus({
    required this.state,
    required this.hasRow,
    required this.streak,
    required this.todayCounted,
    this.announcements = const [],
    this.announcementKeys = const {},
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

  /// The SharedPreferences flag of each pending announcement
  /// (`<prefix><userId>_<kind>_<yyyy-MM-dd | goal>`), set once it is shown.
  final Map<BuddyAnnouncement, String> announcementKeys;

  BuddyStatus copyWith({
    List<BuddyAnnouncement>? announcements,
    Map<BuddyAnnouncement, String>? announcementKeys,
  }) => BuddyStatus(
    state: state,
    hasRow: hasRow,
    streak: streak,
    todayCounted: todayCounted,
    announcements: announcements ?? this.announcements,
    announcementKeys: announcementKeys ?? this.announcementKeys,
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

  /// A [refresh] queued behind other work and not started yet. Another
  /// refresh for the same user and build joins it instead of queuing a
  /// second one: it will fetch the same fresh data.
  ({Ref ref, String userId, Future<void> done})? _queuedRefresh;

  /// Flags of the announcements marked shown in this session. Keeps an
  /// evaluation that read the flags before they were written from bringing
  /// them back.
  final Set<String> _shownKeys = {};

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
    final queued = _queuedRefresh;
    if (queued != null &&
        identical(queued.ref, opRef) &&
        queued.userId == userId) {
      return queued.done;
    }
    late final Future<void> done;
    done = _serialized(() async {
      if (identical(_queuedRefresh?.done, done)) _queuedRefresh = null;
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
    _queuedRefresh = (ref: opRef, userId: userId, done: done);
    return done;
  }

  /// Renames the Buddy (trimmed, 1–20 characters) and creates the row if
  /// missing. Throws [ArgumentError] for an invalid name.
  Future<void> setName(String name) async {
    if (!AppConstants.isValidBuddyName(name)) {
      throw ArgumentError.value(
        name,
        'name',
        'Der Name muss 1 bis ${AppConstants.buddyNameMaxLength} Zeichen '
            'lang sein.',
      );
    }
    final trimmed = name.trim();
    await _mutate('setName', (s) => s.copyWith(name: trimmed));
  }

  /// Sets or clears the streak goal; creates the row if missing.
  Future<void> setStreakGoal(int? goal) =>
      _mutate('setStreakGoal', (s) => s.copyWith(streakGoal: goal));

  /// Marks the Buddy onboarding as done and grants the gift saver (capped at
  /// [maxStreakSavers]). Idempotent: once `onboardingCompletedAt` is set,
  /// nothing changes. Creates the row if missing. Completes with whether a
  /// saver was actually added (not with a full stock, without
  /// [grantGiftSaver] or when the onboarding was already completed).
  Future<bool> completeOnboarding({bool grantGiftSaver = true}) async {
    final now = ref.read(buddyTodayProvider)();
    var granted = false;
    await _mutate('completeOnboarding', (s) {
      if (s.onboardingCompletedAt != null) return s;
      final savers = grantGiftSaver
          ? math.min(maxStreakSavers, s.savers + 1)
          : s.savers;
      granted = savers > s.savers;
      return s.copyWith(onboardingCompletedAt: now, savers: savers);
    });
    return granted;
  }

  /// Records that the UI has played [shown]: drops them from the pending
  /// announcements and sets their flags, so they never come again. Also
  /// works while the Buddy reloads for the same user. A failing flag write
  /// is logged (the message may then repeat after a restart).
  Future<void> markAnnouncementsShown(List<BuddyAnnouncement> shown) async {
    final current = state;
    final status = current.value;
    if (status == null || shown.isEmpty) return;
    // While another user's Buddy loads, the previous value isn't theirs.
    if (current.isLoading &&
        status.state.userId != ref.read(currentUserIdProvider)) {
      return;
    }
    final keys = [for (final a in shown) ?status.announcementKeys[a]];
    _shownKeys.addAll(keys);
    if (status.announcements.any(shown.contains)) {
      final rest = status.announcements.where((a) => !shown.contains(a));
      state = AsyncData(
        status.copyWith(
          announcements: rest.toList(),
          announcementKeys: {
            for (final a in rest) a: ?status.announcementKeys[a],
          },
        ),
      );
    }
    if (keys.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in keys) {
        await prefs.setBool(key, true);
      }
    } catch (e, st) {
      _log.error('Storing the announcement flags failed', e, st);
    }
  }

  /// The signed-in user's stored row (null without one): read once without
  /// retries, evaluating and saving nothing. For a quick "does this account
  /// already have a Buddy?". Throws when it can't be read.
  Future<BuddyState?> fetchStoredRow() {
    final userId = _signedInUserId();
    if (userId == null) {
      return Future<BuddyState?>.error(
        StateError('fetchStoredRow: not signed in'),
      );
    }
    return ref.read(buddyRepositoryProvider).fetch(userId, retry: false);
  }

  /// Right after sign-up the reactive user id can lag behind the auth
  /// repository (like ProfileNotifier, fall back to its current user).
  String? _signedInUserId() =>
      ref.read(currentUserIdProvider) ??
      ref.read(authRepositoryProvider).currentUser?.id;

  Future<void> _mutate(
    String action,
    BuddyState Function(BuddyState current) change,
  ) {
    final userId = _signedInUserId();
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
  /// no rewards) when missing. Reads retry the fetch; a mutation ([change])
  /// tries once, so a failing write surfaces right away.
  Future<BuddyStatus> _sync(
    String userId, {
    BuddyState Function(BuddyState current)? change,
  }) async {
    final repo = ref.read(buddyRepositoryProvider);
    final entries = ref.read(entryRepositoryProvider);
    final today = startOfDay(ref.read(buddyTodayProvider)());
    // The first window's activity days load alongside the row.
    final firstWindow = entries.fetchActivityDays(
      userId: userId,
      since: addDays(today, -_initialWindowDays),
    );
    final BuddyState? row;
    try {
      row = await repo.fetch(userId, retry: change == null);
    } catch (_) {
      firstWindow.ignore();
      rethrow;
    }
    final hasRow = row != null;
    final stored = (row ?? const BuddyState()).copyWith(userId: userId);

    final evaluation = await _evaluate(
      entries,
      userId,
      stored,
      today,
      firstWindow: firstWindow,
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

    final announcements = hasRow
        ? await _announce(userId, evaluation, today)
        : const <BuddyAnnouncement, String>{};
    return BuddyStatus(
      state: next,
      hasRow: hasRow || change != null,
      streak: evaluation.streak,
      todayCounted: evaluation.todayCounted,
      announcements: announcements.keys.toList(),
      announcementKeys: announcements,
    );
  }

  /// Evaluates [state] over a window of activity days ([firstWindow]: the
  /// days of the last [_initialWindowDays]) that is doubled (always from the
  /// original [state]) while the streak reaches its start. Each extension
  /// fetches only the older days it adds.
  Future<StreakEvaluation> _evaluate(
    EntryRepository entries,
    String userId,
    BuddyState state,
    DateTime today, {
    required Future<Set<DateTime>> firstWindow,
    required bool initialize,
  }) async {
    var windowDays = _initialWindowDays;
    var windowStart = addDays(today, -windowDays);
    var days = await firstWindow;
    while (true) {
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
      final olderStart = addDays(today, -windowDays);
      final older = await entries.fetchActivityDays(
        userId: userId,
        since: olderStart,
        until: windowStart,
      );
      days = {...older, ...days};
      windowStart = olderStart;
    }
  }

  /// The announcements for [evaluation] whose flag is not set yet, in
  /// order, each with its flag: one per user, kind and day, `streakBroken`
  /// per break, `goalReached` per goal. Only [markAnnouncementsShown] sets
  /// the flags.
  Future<Map<BuddyAnnouncement, String>> _announce(
    String userId,
    StreakEvaluation evaluation,
    DateTime today,
  ) async {
    final day = formatIsoDate(today);
    final suffixes = <BuddyAnnouncement, String>{
      if (evaluation.consumedDays.isNotEmpty) BuddyAnnouncement.saverUsed: day,
      if (evaluation.brokenAfter case final broken?)
        BuddyAnnouncement.streakBroken: formatIsoDate(broken),
      if (evaluation.saversEarned > 0) BuddyAnnouncement.saverEarned: day,
      if (evaluation.goalReached)
        BuddyAnnouncement.goalReached: '${evaluation.next.streakGoal}',
    };
    final keys = {
      for (final MapEntry(key: kind, value: suffix) in suffixes.entries)
        kind:
            '${AppConstants.keyBuddyAnnouncedPrefix}${userId}_${kind.name}_'
            '$suffix',
    };
    if (keys.isEmpty) return keys;
    try {
      final prefs = await SharedPreferences.getInstance();
      keys.removeWhere((_, key) => prefs.getBool(key) ?? false);
    } catch (e, st) {
      // Better to repeat a message than to lose a one-shot one.
      _log.error('Announcement flags unavailable', e, st);
    }
    return keys;
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

  /// [fresh] plus the not yet played announcements of the same user, minus
  /// those marked shown meanwhile.
  BuddyStatus _withPending(String userId, BuddyStatus fresh) {
    final current = state.value;
    final pending = current != null && current.state.userId == userId
        ? current
        : null;
    final pendingKinds = pending?.announcements ?? const [];
    final keys = {...fresh.announcementKeys, ...?pending?.announcementKeys};
    final announcements = [
      ...pendingKinds,
      ...fresh.announcements.where((a) => !pendingKinds.contains(a)),
    ].where((a) => !_shownKeys.contains(keys[a])).toList();
    return fresh.copyWith(
      announcements: announcements,
      announcementKeys: {for (final a in announcements) a: ?keys[a]},
    );
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
