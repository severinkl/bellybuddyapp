import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/coalesced_runner.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';
import 'entries_provider.dart';
import 'today_provider.dart';

/// A value the signed-in user's entries over a window up to today give
/// ([compute]), kept current:
///
/// - after every entry write ([entriesRevisionProvider]: a log, an edit, a
///   move, a delete), whoever made it;
/// - when the day changes ([todayProvider]: at local midnight, or back in
///   the foreground after the device slept through it), so the window
///   moves on; a new day while unwatched (e.g. on a hidden tab) is caught
///   up once watched again;
/// - on [refresh].
///
/// A write or a new day during a load is fetched after it. Those refetches
/// leave the state [AsyncData]: the previous value stays meanwhile.
///
/// After a user change Riverpod keeps the previous user's value in the
/// state while the new user's value loads ([AsyncValue.isReloading]) and
/// when that load fails (an [AsyncError] with a value): read it through
/// `currentValue` (`utils/settled_value.dart`).
abstract class EntryWindowNotifier<T> extends AsyncNotifier<T> {
  /// Where failures are logged.
  AppLogger get log;

  /// What the log lines call the value, e.g. „insights".
  String get subject;

  /// The value for [userId] (null: signed out) as of now.
  Future<T> compute(String? userId);

  /// Counts computations outside build, in the order they start.
  int _seq = 0;

  /// The [_seq] of the last computation outside build that applied its
  /// result: a result applies only if its computation started after that
  /// one, so an older one never overwrites a newer one, and when the newest
  /// fails, an older one that succeeds (with a write the state lacks) still
  /// applies.
  int _appliedSeq = 0;

  /// The [_refetch]es, coalesced per build (its ref): another write or new
  /// day for it meanwhile asks for one more.
  final _refetches = CoalescedRunner();

  @override
  Future<T> build() async {
    final userId = ref.watch(currentUserIdProvider);
    ref.listen(entriesRevisionProvider, (_, _) => unawaited(_refetch()));
    // Listened, not watched: a rebuild would hide the value while the new
    // day loads. Unwatched (e.g. Home on a hidden tab), a new day waits:
    // resuming replays it, inside a life-cycle callback where ref can't be
    // used, hence the microtask.
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
      return await compute(userId);
    } catch (e, st) {
      log.error('Loading the $subject failed', e, st);
      rethrow;
    }
  }

  /// Computes the value again. While a load runs (the first one, or the
  /// one after a user change), waits for it instead. Never throws: on
  /// failure the last value stays (an error without one stays an error).
  /// A result applies only if no newer computation has applied one
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
  Future<void> _refetch() {
    final opRef = ref;
    return _refetches.run(key: opRef, () async {
      while (opRef.mounted && state.isLoading) {
        await _loadDone();
      }
      // A rebuild (another user) meanwhile loads on its own, after this.
      if (opRef.mounted) await _fetchAndApply();
    });
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
      final value = await compute(userId);
      if (seq > _appliedSeq && opRef.isCurrentUser(userId)) {
        _appliedSeq = seq;
        state = AsyncData(value);
      }
    } catch (e, st) {
      log.error('Refreshing the $subject failed', e, st);
    }
  }
}
