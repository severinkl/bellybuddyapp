import 'dart:math' as math;

/// How far the user is toward the first patterns („Muster"): they unlock
/// with [daysNeeded] distinct local days with any entry and
/// [gutFeelingsNeeded] gut-feeling entries in the last [windowDays] local
/// days, today included.
class InsightProgress {
  const InsightProgress({
    required this.activeDays,
    required this.gutFeelingEntries,
  });

  /// The window's length in local calendar days, today included.
  static const windowDays = 30;
  static const daysNeeded = 7;
  static const gutFeelingsNeeded = 3;

  /// Distinct local days in the window with any entry.
  final int activeDays;

  /// Gut-feeling entries in the window.
  final int gutFeelingEntries;

  bool get unlocked => daysLeft == 0 && gutFeelingsLeft == 0;

  /// Days with entries still missing (never negative).
  int get daysLeft => math.max(0, daysNeeded - activeDays);

  /// Gut-feeling entries still missing (never negative).
  int get gutFeelingsLeft => math.max(0, gutFeelingsNeeded - gutFeelingEntries);

  @override
  bool operator ==(Object other) =>
      other is InsightProgress &&
      other.activeDays == activeDays &&
      other.gutFeelingEntries == gutFeelingEntries;

  @override
  int get hashCode => Object.hash(activeDays, gutFeelingEntries);

  @override
  String toString() =>
      'InsightProgress(activeDays: $activeDays, '
      'gutFeelingEntries: $gutFeelingEntries)';
}
