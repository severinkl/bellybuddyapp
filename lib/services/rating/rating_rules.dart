import '../../config/constants.dart';
import '../../models/gut_feeling_entry.dart';
import '../../utils/date_format_utils.dart';
import '../../utils/gut_feeling_rating.dart';

/// Whether the store rating may be requested again: not yet in
/// [currentVersion] ([askedVersion] is the version of the last request) and
/// at least [AppConstants.ratingAskMinDays] calendar days after [lastAsk]
/// (never asked: no wait). [lastAsk] and [today] are local calendar days.
bool ratingAskAllowed({
  required String currentVersion,
  required String? askedVersion,
  required DateTime? lastAsk,
  required DateTime today,
}) {
  if (askedVersion == currentVersion) return false;
  return lastAsk == null ||
      daysBetween(lastAsk, today) >= AppConstants.ratingAskMinDays;
}

/// Whether one of [entries] is of [today] (by its wall-clock date, never
/// converted) and rated „Schlecht".
bool hasHardEntryToday(Iterable<GutFeelingEntry> entries, DateTime today) =>
    entries.any(
      (e) =>
          isSameDay(e.trackedAt, today) &&
          calculateGutFeelingRating(e).level == GutFeelingRatingLevel.schlecht,
    );
