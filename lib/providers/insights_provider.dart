import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/insight_source.dart';
import '../models/insights.dart';
import '../repositories/entry_repository.dart';
import '../services/insights/insights_engine.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';
import 'buddy_provider.dart';
import 'entries_provider.dart';

/// The signed-in user's [Insights] over the last 30 local days as of the
/// app's clock ([buddyClockProvider]); while signed out, those of no
/// entries (progress 0/0, 30 empty days, nothing yet).
///
/// Computed again:
/// - after every entry write ([entriesRevisionProvider]: a log, an edit, a
///   move, a delete), whoever made it;
/// - at local midnight, so the window moves on (while watched; a midnight
///   missed while unwatched, e.g. on a hidden tab, is caught up once
///   watched again);
/// - on [refresh] (Home's load and pull-to-refresh).
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

  /// Counts refresh fetches; only the latest one applies its result.
  int _seq = 0;

  /// The app's clock, kept for the life-cycle callbacks, where [ref] can't
  /// be used.
  late DateTime Function() _clock;

  Timer? _midnightTimer;

  /// The local midnight [_midnightTimer] waits for.
  DateTime? _nextMidnight;

  @override
  Future<Insights> build() async {
    final userId = ref.watch(currentUserIdProvider);
    _clock = ref.read(buddyClockProvider);
    ref
      ..listen(entriesRevisionProvider, (_, _) => unawaited(refresh()))
      ..onCancel(_disarmMidnight)
      ..onResume(_resumeMidnight)
      ..onDispose(_disarmMidnight);
    _armMidnight();
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
  /// error). A result applies only if no newer refresh started meanwhile
  /// and the user is still the same.
  Future<void> refresh() async {
    if (state.isLoading) {
      try {
        await future;
      } catch (_) {
        // Logged by build.
      }
      return;
    }
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
    final now = _clock();
    if (userId == null) return computeInsights(_noEntries, now);
    final source = await ref
        .read(entryRepositoryProvider)
        .fetchInsightSource(userId: userId, now: now);
    return computeInsights(source, now);
  }

  /// A one-shot timer to the next local midnight that refreshes and arms
  /// the next one.
  void _armMidnight() {
    _midnightTimer?.cancel();
    final now = _clock().toLocal();
    final midnight = addDays(startOfDay(now), 1);
    _nextMidnight = midnight;
    _midnightTimer = Timer(midnight.difference(now), () {
      _armMidnight();
      unawaited(refresh());
    });
  }

  void _disarmMidnight() {
    _midnightTimer?.cancel();
    _midnightTimer = null;
  }

  /// Watched again: arms the timer, and refreshes when the midnight it
  /// waited for passed meanwhile (right after this life-cycle callback).
  void _resumeMidnight() {
    final missed = _nextMidnight;
    _armMidnight();
    if (missed == null || _clock().isBefore(missed)) return;
    final opRef = ref;
    scheduleMicrotask(() {
      if (opRef.mounted) unawaited(refresh());
    });
  }
}

/// No automatic rebuild retries: a failed load stays an error until the
/// next entry write, midnight or refresh.
Duration? _noRetry(int retryCount, Object error) => null;

/// What the Buddy noticed in the last 30 days of entries: Home's card and
/// the Muster page.
final insightsProvider = AsyncNotifierProvider<InsightsNotifier, Insights>(
  InsightsNotifier.new,
  retry: _noRetry,
);
