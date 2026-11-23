import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/insight_source.dart';
import '../models/insights.dart';
import '../repositories/entry_repository.dart';
import '../services/insights/insights_engine.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';
import 'buddy_provider.dart';
import 'entries_provider.dart';
import 'today_provider.dart';

/// The signed-in user's [Insights] over the last 30 local days as of the
/// app's clock ([buddyClockProvider]); while signed out, those of no
/// entries (progress 0/0, 30 empty days, nothing yet).
///
/// Computed again:
/// - after every entry write ([entriesRevisionProvider]: a log, an edit, a
///   move, a delete), whoever made it;
/// - when the day changes ([todayProvider]: at local midnight, or back in
///   the foreground after the device slept through it), so the window
///   moves on; a new day while unwatched (e.g. on a hidden tab) is caught
///   up once watched again;
/// - on [refresh] (Home's load and pull-to-refresh).
///
/// A write or a new day during a load is fetched after it.
///
/// After a user change Riverpod keeps the previous user's value in the
/// state while the new user's insights load ([AsyncValue.isReloading]) and
/// when that load fails (an [AsyncError] with a value): show a value only
/// from [AsyncData] (e.g. through [AsyncValue.whenData]).
class InsightsNotifier extends AsyncNotifier<Insights> {
  static const _log = AppLogger('Insights');

  static const _noEntries = InsightSource(
    meals: [],
    gutFeelings: [],
    activityInstants: [],
  );

  /// Counts computations outside build; only the latest one applies its
  /// result.
  int _seq = 0;

  /// The ref of the build whose [_refetch] runs; another write or new day
  /// for it meanwhile only marks [_again].
  Ref? _refetching;

  /// Something changed after the running [_refetch] fetched: it fetches
  /// once more.
  bool _again = false;

  @override
  Future<Insights> build() async {
    final userId = ref.watch(currentUserIdProvider);
    ref.listen(entriesRevisionProvider, (_, _) => unawaited(_refetch()));
    // Listened, not watched: a rebuild would hide the insights while the
    // new day loads. Unwatched (e.g. Home on a hidden tab), a new day
    // waits: resuming replays it, inside a life-cycle callback where ref
    // can't be used, hence the microtask.
    final newDay = ref.listen(todayProvider, (_, _) {
      final opRef = ref;
      scheduleMicrotask(() {
        if (opRef.mounted) unawaited(_refetch());
      });
    });
    ref
      ..onCancel(newDay.pause)
      ..onResume(newDay.resume);
    try {
      return await _compute(userId);
    } catch (e, st) {
      _log.error('Loading the insights failed', e, st);
      rethrow;
    }
  }

  /// Computes the insights again. While a load runs (the first one, or the
  /// one after a user change), waits for it instead. Never throws: on
  /// failure the last insights stay (an error without them stays an
  /// error). A result applies only if no newer computation started
  /// meanwhile and the user is still the same.
  Future<void> refresh() async {
    if (state.isLoading) {
      await _loadDone();
      return;
    }
    await _fetchAndApply();
  }

  /// After an entry write or on a new day: a running load may have fetched
  /// before it, so this waits for that load to apply and then computes
  /// again (fetching only afterwards, an older load never overwrites it).
  ///
  /// Coalesced: while this runs, more writes only ask for one more fetch
  /// after the running one, so a burst of writes fetches at most twice.
  Future<void> _refetch() async {
    final opRef = ref;
    if (identical(_refetching, opRef)) {
      _again = true;
      return;
    }
    _refetching = opRef;
    try {
      do {
        while (opRef.mounted && state.isLoading) {
          await _loadDone();
        }
        // A rebuild (another user) meanwhile loads on its own, after this.
        if (!opRef.mounted) return;
        _again = false;
        await _fetchAndApply();
      } while (_again);
    } finally {
      if (identical(_refetching, opRef)) _refetching = null;
    }
  }

  Future<void> _loadDone() async {
    try {
      await future;
    } catch (_) {
      // Logged by build.
    }
  }

  Future<void> _fetchAndApply() async {
    final opRef = ref;
    final userId = opRef.read(currentUserIdProvider);
    final seq = ++_seq;
    try {
      final insights = await _compute(userId);
      if (seq == _seq &&
          opRef.mounted &&
          opRef.read(currentUserIdProvider) == userId) {
        state = AsyncData(insights);
      }
    } catch (e, st) {
      _log.error('Refreshing the insights failed', e, st);
    }
  }

  Future<Insights> _compute(String? userId) async {
    final now = ref.read(buddyClockProvider)();
    if (userId == null) return computeInsights(_noEntries, now);
    final source = await ref
        .read(entryRepositoryProvider)
        .fetchInsightSource(userId: userId, now: now);
    return computeInsights(source, now);
  }
}

/// No automatic rebuild retries: a failed load stays an error until the
/// next entry write, new day or refresh.
Duration? _noRetry(int retryCount, Object error) => null;

/// What the Buddy noticed in the last 30 days of entries: Home's card and
/// the Muster page.
final insightsProvider = AsyncNotifierProvider<InsightsNotifier, Insights>(
  InsightsNotifier.new,
  retry: _noRetry,
);
