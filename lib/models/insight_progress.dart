import 'dart:math' as math;

import 'insight_rules.dart';

/// How far the user is toward the first patterns („Muster"): they unlock
/// with [InsightRules.daysNeeded] distinct local days with any entry and
/// [InsightRules.gutFeelingsNeeded] gut-feeling entries in the last
/// [InsightRules.windowDays] local days, today included.
class InsightProgress {
  const InsightProgress({
    required this.activeDays,
    required this.gutFeelingEntries,
  });

  /// Distinct local days in the window with any entry.
  final int activeDays;

  /// Gut-feeling entries in the window.
  final int gutFeelingEntries;

  bool get unlocked => daysLeft == 0 && gutFeelingsLeft == 0;

  /// Days with entries still missing (never negative).
  int get daysLeft => math.max(0, InsightRules.daysNeeded - activeDays);

  /// Gut-feeling entries still missing (never negative).
  int get gutFeelingsLeft =>
      math.max(0, InsightRules.gutFeelingsNeeded - gutFeelingEntries);

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
