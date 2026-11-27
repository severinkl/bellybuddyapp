import '../../models/gut_feeling_entry.dart';
import '../../models/insights.dart';
import '../../utils/gut_feeling_rating.dart';

DayClass _classOf(GutFeelingRatingLevel level) => switch (level) {
  GutFeelingRatingLevel.spiGut || GutFeelingRatingLevel.gut => DayClass.good,
  GutFeelingRatingLevel.mittel => DayClass.medium,
  GutFeelingRatingLevel.schlecht => DayClass.hard,
};

/// The class of one entry on its own, from its [gutFeelingScore].
DayClass entryClassOf(GutFeelingEntry entry) =>
    _classOf(gutFeelingLevelFor(gutFeelingScore(entry)));

/// The class of a day with [entries] (at least one), from the mean of their
/// [gutFeelingScore]s.
///
/// Exact at the half-step thresholds: the mean is one division of two whole
/// numbers, rounded once, and a mean that is not on a half step is at least
/// `1 / (2 · count)` away from it, far more than that rounding can move it.
DayClass dayClassOf(List<GutFeelingEntry> entries) {
  var sum = 0;
  for (final e in entries) {
    sum += gutFeelingScore(e);
  }
  return _classOf(gutFeelingLevelFor(sum / entries.length));
}
