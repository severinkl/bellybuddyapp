import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/insight_progress.dart';
import '../repositories/entry_repository.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';
import 'buddy_events_provider.dart';
import 'buddy_provider.dart';

/// The signed-in user's [InsightProgress] as of the app's clock
/// ([buddyClockProvider]); zero progress while signed out. Fetched again
/// after every log ([buddyEventsProvider]) and on [refresh] (Home's load and
/// pull-to-refresh).
class InsightProgressNotifier extends AsyncNotifier<InsightProgress> {
  static const _log = AppLogger('InsightProgress');

  static const _none = InsightProgress(activeDays: 0, gutFeelingEntries: 0);

  @override
  Future<InsightProgress> build() async {
    final userId = ref.watch(currentUserIdProvider);
    ref.listen(buddyEventsProvider, (_, event) {
      if (event != null) unawaited(refresh());
    });
    if (userId == null) return _none;
    try {
      return await _fetch(userId);
    } catch (e, st) {
      _log.error('Loading the insight progress failed', e, st);
      rethrow;
    }
  }

  /// Fetches the progress again. While the first load still runs, waits for
  /// it instead. Never throws: on failure the last progress stays (an error
  /// without one stays an error).
  Future<void> refresh() async {
    if (state.isLoading && !state.hasValue) {
      try {
        await future;
      } catch (_) {
        // Logged by build; the card stays hidden.
      }
      return;
    }
    final opRef = ref;
    final userId = opRef.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      final progress = await _fetch(userId);
      // A rebuild meanwhile (another user) has its own load.
      if (opRef.mounted) state = AsyncData(progress);
    } catch (e, st) {
      _log.error('Refreshing the insight progress failed', e, st);
    }
  }

  Future<InsightProgress> _fetch(String userId) => ref
      .read(entryRepositoryProvider)
      .fetchInsightProgress(
        userId: userId,
        now: ref.read(buddyClockProvider)(),
      );
}

/// No automatic rebuild retries: a failed load hides the card until the next
/// log or refresh.
Duration? _noRetry(int retryCount, Object error) => null;

/// Stage 1's progress toward the first patterns on Home; Stage 2 replaces it
/// with the full insights.
final insightProgressProvider =
    AsyncNotifierProvider<InsightProgressNotifier, InsightProgress>(
      InsightProgressNotifier.new,
      retry: _noRetry,
    );
