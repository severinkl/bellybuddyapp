import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/buddy/buddy_mood_logic.dart';
import '../services/buddy/log_moment.dart';
import 'buddy_provider.dart';
import 'care_log_provider.dart';

/// The [LogMoment] of an entry of [kind] at [trackedAt], as the app knows
/// it now. Trackers call it right before they write the entry.
LogMoment captureLogMoment(
  WidgetRef ref, {
  required EntryKind kind,
  required DateTime trackedAt,
}) => logMomentFor(
  need: careNeedOf(kind),
  trackedAt: trackedAt,
  care: ref.read(careLogProvider),
  now: ref.read(buddyClockProvider)(),
  buddy: ref.read(buddyProvider).value,
);
