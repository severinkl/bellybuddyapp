import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/buddy/buddy_mood_logic.dart';
import '../services/buddy/log_moment.dart';
import '../utils/settled_value.dart';
import 'buddy_provider.dart';
import 'insights_provider.dart';
import 'care_log_provider.dart';

/// The [LogMoment] of an entry of [kind] at [trackedAt], as Home shows the
/// needs now ([careNowProvider]). Trackers call it right before they write
/// the entry.
LogMoment captureLogMoment(
  WidgetRef ref, {
  required EntryKind kind,
  required DateTime trackedAt,
  LogSentiment sentiment = LogSentiment.good,
}) {
  final care = ref.read(careNowProvider);
  return logMomentFor(
    kind: kind,
    trackedAt: trackedAt,
    care: care.log,
    now: care.at,
    // Settled values only: a reload or an error keeps the previous value,
    // which may be another user's.
    buddy: ref.read(buddyProvider).settledValue,
    insights: ref.read(insightsProvider).settledValue,
    sentiment: sentiment,
  );
}
