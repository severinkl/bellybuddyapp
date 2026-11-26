import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/buddy_events_provider.dart';
import '../../providers/buddy_provider.dart';
import '../../providers/log_moment.dart';
import '../../services/buddy/buddy_mood_logic.dart';
import '../../services/buddy/log_moment.dart';
import '../../utils/gut_feeling_rating.dart';
import '../../utils/save_helper.dart';

/// A tracker that logs new entries: [logEntry] captures what an entry does
/// ([logMoment], which its success page shows), saves it and tells the
/// Buddy.
mixin EntryLogger<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// What the latest new entry does, captured right before its write, as
  /// Home showed the needs then ([captureLogMoment]).
  LogMoment? logMoment;

  /// Logs a new entry of [kind] at [trackedAt] (a Bauchgefühl felt
  /// [gutFeeling]): captures its [logMoment], runs [save] (a failure shows
  /// the error SnackBar, see [saveWithFeedback]) and, once the entry is
  /// stored ([stored]; by default when [save] succeeded) and the tracker
  /// still shows, tells the Buddy ([BuddyLogEvent], at the app's clock).
  /// True when it did.
  Future<bool> logEntry({
    required EntryKind kind,
    required DateTime trackedAt,
    LogSentiment sentiment = LogSentiment.good,
    GutFeelingRatingLevel? gutFeeling,
    required Future<void> Function() save,
    bool Function()? stored,
  }) async {
    logMoment = captureLogMoment(
      ref,
      kind: kind,
      trackedAt: trackedAt,
      sentiment: sentiment,
      gutFeeling: gutFeeling,
    );
    final saved = await saveWithFeedback(context, save);
    if (!saved || !mounted || !(stored?.call() ?? true)) return false;
    ref
        .read(buddyEventsProvider.notifier)
        .emit(
          BuddyLogEvent(
            kind,
            sentiment,
            at: ref.read(buddyClockProvider)(),
            trackedAt: trackedAt,
          ),
        );
    return true;
  }
}
