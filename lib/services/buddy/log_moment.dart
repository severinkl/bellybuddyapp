import '../../models/insight_progress.dart';
import '../../models/insights.dart';
import '../../providers/buddy_provider.dart';
import '../../utils/date_format_utils.dart';
import '../insights/insight_copy.dart';
import 'buddy_mood_logic.dart';
import 'care_meters.dart';
import 'daily_care.dart';

/// What a new entry does at the moment it is saved: its need's level before
/// and with it, and the streak day it ignites. The success page shows it.
class LogMoment {
  const LogMoment({
    required this.need,
    this.from,
    this.to,
    this.ignitesDay,
    this.buddyLine,
  });

  final CareNeed need;

  /// The need's level before / with the entry; null for Klo.
  final double? from, to;

  /// The streak the entry makes when it is today's first; null otherwise.
  final int? ignitesDay;

  /// What the Buddy says instead of his reaction line: how far the first
  /// patterns are; null when he has nothing to add.
  final String? buddyLine;
}

/// The [LogMoment] of an entry for [need] at [trackedAt], saved at [now]
/// with [care] as logged so far. A back-dated entry older than the need's
/// last one leaves its level as it was. It ignites the next streak day when
/// it falls on [now]'s date and nothing counts today yet ([buddy]'s
/// `todayCounted`, [care]).
///
/// The Buddy says how far the first patterns are ([buddyLine]) after
/// today's first good or neutral Bauchgefühl while [insights] are locked,
/// but not when this entry unlocks them.
LogMoment logMomentFor({
  required CareNeed need,
  required DateTime trackedAt,
  required CareLog care,
  required DateTime now,
  BuddyStatus? buddy,
  Insights? insights,
  LogSentiment sentiment = LogSentiment.good,
}) {
  final drain = drainOf(need);
  final last = care.lastAt(need);
  final latest = last == null || trackedAt.isAfter(last) ? trackedAt : last;
  return LogMoment(
    buddyLine: _buddyLine(need, trackedAt, care, now, insights, sentiment),
    need: need,
    from: drain == null ? null : meterLevel(last, now, drain),
    to: drain == null ? null : meterLevel(latest, now, drain),
    ignitesDay:
        buddy != null &&
            !buddy.todayCounted &&
            isSameDay(trackedAt, now) &&
            !care.anyOn(now)
        ? buddy.streak + 1
        : null,
  );
}

String? _buddyLine(
  CareNeed need,
  DateTime trackedAt,
  CareLog care,
  DateTime now,
  Insights? insights,
  LogSentiment sentiment,
) {
  if (need != CareNeed.gutFeeling ||
      sentiment == LogSentiment.bad ||
      insights == null ||
      insights.unlocked ||
      !isSameDay(trackedAt, now) ||
      care.loggedOn(CareNeed.gutFeeling, now)) {
    return null;
  }
  final progress = insights.progress;
  return InsightCopy.journeyFeedback(
    InsightProgress(
      activeDays: progress.activeDays + (care.anyOn(now) ? 0 : 1),
      gutFeelingEntries: progress.gutFeelingEntries + 1,
    ),
  );
}
