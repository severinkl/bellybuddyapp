/// Every threshold of „Dein Verlauf" (`computeProgress`) and of the
/// recent signals the knowledge feed's „Für dich" reads.
abstract final class ProgressRules {
  /// The window: this many Monday weeks, the current one last.
  static const weeks = 12;

  /// A week's symptom means need at least this many gut-feeling entries …
  static const minEntriesForMeans = 3;

  /// … on at least this many days.
  static const minDaysForMeans = 2;

  /// The symptom trend shows with at least this many weeks with means.
  static const minTrendWeeks = 2;

  /// The recent signals cover this many local days, today included …
  static const recentDays = 7;

  /// … and a recent mean needs at least this many values.
  static const recentMinEntries = 3;

  /// A recent symptom or stress mean that counts as „öfter".
  static const recentHigh = 3.0;

  /// At least this many hard (stool_type 1–2) or loose (4–5) Klo entries.
  static const kloMin = 2;

  /// „mehr gute Tage als die Woche davor" needs this many rated days in
  /// both weeks.
  static const minRatedForComparison = 3;
}
