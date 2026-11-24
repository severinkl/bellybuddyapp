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
    required this.kind,
    this.sentiment = LogSentiment.good,
    this.from,
    this.to,
    this.ignitesDay,
    this.buddyLine,
  });

  /// What was logged.
  final EntryKind kind;

  /// How the entry went; a bad one gets the calm page.
  final LogSentiment sentiment;

  /// The need the entry fills.
  CareNeed get need => careNeedOf(kind);

  /// The need's level before / with the entry; null for Klo.
  final double? from, to;

  /// The streak the entry makes when it is today's first; null otherwise.
  final int? ignitesDay;

  /// What the Buddy says instead of his reaction line: how far the first
  /// patterns are; null when he has nothing to add.
  final String? buddyLine;
}

/// The [LogMoment] of an entry of [kind] at [trackedAt], saved at [now]
/// with [care] as logged so far. A back-dated entry older than the need's
/// last one leaves its level as it was. It ignites the next streak day when
/// it falls on [now]'s date and nothing counts today yet ([buddy]'s
/// `todayCounted`, [care]).
///
/// The Buddy says how far the first patterns are ([LogMoment.buddyLine])
/// after today's first good or neutral Bauchgefühl while [insights] are
/// locked, but not when this entry unlocks them. Today adds an active day
/// unless the insights count it already (their journey ends today), so a
/// refresh of theirs that lags behind the care log never miscounts.
LogMoment logMomentFor({
  required EntryKind kind,
  required DateTime trackedAt,
  required CareLog care,
  required DateTime now,
  BuddyStatus? buddy,
  Insights? insights,
  LogSentiment sentiment = LogSentiment.good,
}) {
  final need = careNeedOf(kind);
  final drain = drainOf(need);
  final last = care.lastAt(need);
  final latest = last == null || trackedAt.isAfter(last) ? trackedAt : last;
  final today = isSameDay(trackedAt, now);
  final firstToday = !care.anyOn(now);
  final firstGutFeelingToday =
      need == CareNeed.gutFeeling &&
      today &&
      !care.loggedOn(CareNeed.gutFeeling, now);
  // How far the first patterns are, while locked.
  final progress = insights == null || insights.unlocked
      ? null
      : insights.progress;
  final lastActive = insights?.journey.lastOrNull?.day;
  final countedToday = lastActive != null && isSameDay(lastActive, now);
  return LogMoment(
    kind: kind,
    sentiment: sentiment,
    from: drain == null ? null : meterLevel(last, now, drain),
    to: drain == null ? null : meterLevel(latest, now, drain),
    ignitesDay: buddy != null && !buddy.todayCounted && today && firstToday
        ? buddy.streak + 1
        : null,
    buddyLine:
        firstGutFeelingToday &&
            sentiment != LogSentiment.bad &&
            progress != null
        ? InsightCopy.journeyFeedback(
            InsightProgress(
              activeDays: progress.activeDays + (countedToday ? 0 : 1),
              gutFeelingEntries: progress.gutFeelingEntries + 1,
            ),
          )
        : null,
  );
}
