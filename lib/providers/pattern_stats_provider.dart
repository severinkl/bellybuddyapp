import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pattern_stats.dart';
import '../services/pattern_stats_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';
import 'auth_provider.dart';
import 'entries_provider.dart';

extension PatternStatsStateX on AsyncValue<PatternStats?> {
  /// The server answered 402 `plus_required`: show the lock, not an error.
  bool get isLocked => error is PatternStatsLockedException;
}

/// The signed-in user's 90-day pattern comparison; null while signed out.
/// Fetched on first read, after every entry write and on [refresh]. A 402
/// `plus_required` is an [AsyncError] holding a
/// [PatternStatsLockedException] (see [PatternStatsStateX.isLocked]); any
/// other failure is an ordinary [AsyncError]. Not persisted.
class PatternStatsNotifier extends AsyncNotifier<PatternStats?> {
  static const _log = AppLogger('PatternStats');

  int _seq = 0;
  int _appliedSeq = 0;

  @override
  Future<PatternStats?> build() async {
    final userId = ref.watch(currentUserIdProvider);
    ref.listen(entriesRevisionProvider, (_, _) => unawaited(refresh()));
    if (userId == null) return null;
    try {
      return await ref.read(patternStatsServiceProvider).fetch();
    } catch (e, st) {
      _logFailure('Loading', e, st);
      rethrow;
    }
  }

  /// Fetches again. Never throws: a failure keeps the last value (an error
  /// without one stays an error), except a lock, which replaces it. A
  /// result for another user, or older than one applied, is dropped.
  Future<void> refresh() async {
    final opRef = ref;
    final userId = opRef.read(currentUserIdProvider);
    if (userId == null) return;
    final seq = ++_seq;
    try {
      final value = await opRef.read(patternStatsServiceProvider).fetch();
      if (seq > _appliedSeq && opRef.isCurrentUser(userId)) {
        _appliedSeq = seq;
        state = AsyncData(value);
      }
    } catch (e, st) {
      _logFailure('Refreshing', e, st);
      if (e is PatternStatsLockedException &&
          seq > _appliedSeq &&
          opRef.isCurrentUser(userId)) {
        _appliedSeq = seq;
        state = AsyncError(e, st);
      }
    }
  }

  void _logFailure(String what, Object e, StackTrace st) {
    if (e is PatternStatsLockedException) {
      _log.debug('$what the pattern stats: locked (Plus)');
    } else {
      _log.error('$what the pattern stats failed', e, st);
    }
  }
}

final patternStatsProvider =
    AsyncNotifierProvider.autoDispose<PatternStatsNotifier, PatternStats?>(
      PatternStatsNotifier.new,
      retry: noRetry,
    );
