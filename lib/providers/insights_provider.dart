import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/insight_source.dart';
import '../models/insights.dart';
import '../repositories/entry_repository.dart';
import '../services/insights/insights_engine.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';
import 'buddy_provider.dart';
import 'entry_window_notifier.dart';

/// The signed-in user's [Insights] over the last 30 local days as of the
/// app's clock ([buddyClockProvider]); while signed out, those of no
/// entries (progress 0/0, 30 empty days, nothing yet).
///
/// Computed again after every entry write, on a new day and on [refresh]
/// (Home's load and pull-to-refresh); see [EntryWindowNotifier], also for
/// what the state holds after a user change.
class InsightsNotifier extends EntryWindowNotifier<Insights> {
  static const _log = AppLogger('Insights');

  static const _noEntries = InsightSource(
    meals: [],
    gutFeelings: [],
    activityTimes: [],
  );

  @override
  AppLogger get log => _log;

  @override
  String get subject => 'insights';

  @override
  Future<Insights> compute(String? userId) async {
    final now = ref.read(buddyClockProvider)();
    if (userId == null) return computeInsights(_noEntries, now);
    final source = await ref
        .read(entryRepositoryProvider)
        .fetchInsightSource(userId: userId, now: now);
    return computeInsights(source, now);
  }
}

/// What the Buddy noticed in the last 30 days of entries: Home's card and
/// the Muster page. No automatic rebuild retries: a failed load stays an
/// error until the next entry write, new day or refresh.
final insightsProvider = AsyncNotifierProvider<InsightsNotifier, Insights>(
  InsightsNotifier.new,
  retry: noRetry,
);
