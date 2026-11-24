/// A share as a fraction of whole numbers, so thresholds compare exactly.
typedef InsightShare = ({int numerator, int denominator});

/// Every threshold of the insights in one place: the window, the unlock
/// (`InsightProgress`), the computation (`computeInsights`) and what the
/// Muster page and Home's card show of it.
abstract final class InsightRules {
  /// The window's length in local calendar days, today included.
  static const windowDays = 30;

  /// The first patterns unlock with this many distinct local days with any
  /// entry in the window …
  static const daysNeeded = 7;

  /// … and this many gut-feeling entries.
  static const gutFeelingsNeeded = 3;

  /// The ingredients that count for a good or a hard day are those of the
  /// meals in this long before its first entry of the day's class.
  static const mealsBefore = Duration(hours: 24);

  // The good and the hard days („Deine guten/schweren Tage").

  /// A column needs this many days of its class to be shown; below, the
  /// page says „Noch zu wenige gute/schwere Tage".
  static const minColumnDays = 3;

  /// „oft dabei": there on at least this many days of the column …
  static const minOftenCount = 2;

  /// … and on at least this share of them …
  static const InsightShare minOftenShare = (numerator: 1, denominator: 2);

  /// … at most this many per column.
  static const maxOften = 5;

  // „Fällt mir auf".

  /// The section shows only with at least this many hard days in the
  /// window.
  static const minHardDays = 3;

  /// An item was there on at least this share of the hard days …
  static const InsightShare minHardShare = (numerator: 1, denominator: 2);

  /// … and that share is at least this much above its share of the good
  /// days (0 without good days).
  static const InsightShare minShareGap = (numerator: 1, denominator: 4);

  /// A shown item was there on at least this many hard days …
  static const minNoticedHard = 3;

  /// … one there on exactly this many is shown „noch unsicher".
  static const uncertainHard = 2;

  /// At most this many shown items, then at most [maxUncertain] uncertain
  /// ones.
  static const maxNoticed = 5;
  static const maxUncertain = 3;
}
