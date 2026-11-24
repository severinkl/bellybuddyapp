import '../../providers/buddy_provider.dart';
import '../../utils/date_format_utils.dart';
import 'care_meters.dart';
import 'daily_care.dart';

/// What a new entry does at the moment it is saved: its need's level before
/// and with it, and the streak day it ignites. The success page shows it.
class LogMoment {
  const LogMoment({required this.need, this.from, this.to, this.ignitesDay});

  final CareNeed need;

  /// The need's level before / with the entry; null for Klo.
  final double? from, to;

  /// The streak the entry makes when it is today's first; null otherwise.
  final int? ignitesDay;
}

/// The [LogMoment] of an entry for [need] at [trackedAt], saved at [now]
/// with [care] as logged so far. A back-dated entry older than the need's
/// last one leaves its level as it was. It ignites the next streak day when
/// it falls on [now]'s date and nothing counts today yet ([buddy]'s
/// `todayCounted`, [care]).
LogMoment logMomentFor({
  required CareNeed need,
  required DateTime trackedAt,
  required CareLog care,
  required DateTime now,
  BuddyStatus? buddy,
}) {
  final drain = drainOf(need);
  final last = care.lastAt(need);
  final latest = last == null || trackedAt.isAfter(last) ? trackedAt : last;
  return LogMoment(
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
