import 'package:flutter/foundation.dart' show listEquals;

import 'gut_feeling_entry.dart';
import 'insights.dart';
import 'progress_rules.dart';

/// Everything „Dein Verlauf" is computed from, loaded once for the window.
class ProgressSource {
  const ProgressSource({
    required this.gutFeelings,
    required this.toilets,
    required this.otherTimes,
  });

  /// Gut-feeling entries since the window's first Monday.
  final List<GutFeelingEntry> gutFeelings;

  /// Klo entries since the window's first Monday: when, and the stool type
  /// (1–5).
  final List<({DateTime trackedAt, int stoolType})> toilets;

  /// `tracked_at` of the meals and drinks since the window's first Monday.
  final List<DateTime> otherTimes;
}

/// The mean of each gut symptom (1–5, higher = worse) over some entries.
class SymptomMeans {
  const SymptomMeans({
    required this.bloating,
    required this.gas,
    required this.cramps,
    required this.fullness,
  });

  final double bloating;
  final double gas;
  final double cramps;
  final double fullness;

  @override
  bool operator ==(Object other) =>
      other is SymptomMeans &&
      other.bloating == bloating &&
      other.gas == gas &&
      other.cramps == cramps &&
      other.fullness == fullness;

  @override
  int get hashCode => Object.hash(bloating, gas, cramps, fullness);

  @override
  String toString() =>
      'SymptomMeans(bloating: $bloating, gas: $gas, cramps: $cramps, '
      'fullness: $fullness)';
}

/// One day of a [ProgressWeek].
class ProgressDay {
  const ProgressDay({
    required this.day,
    required this.dayClass,
    required this.active,
    required this.future,
  });

  /// The local day, at midnight.
  final DateTime day;

  /// The Muster's class (`dayClassOf`); [DayClass.none] without a
  /// gut-feeling entry.
  final DayClass dayClass;

  /// Any entry of any table that day.
  final bool active;

  /// After today: shown blank, never counted.
  final bool future;

  @override
  bool operator ==(Object other) =>
      other is ProgressDay &&
      other.day == day &&
      other.dayClass == dayClass &&
      other.active == active &&
      other.future == future;

  @override
  int get hashCode => Object.hash(day, dayClass, active, future);

  @override
  String toString() =>
      'ProgressDay($day, ${dayClass.name}, active: $active, future: $future)';
}

/// One Monday week of the window.
class ProgressWeek {
  const ProgressWeek({
    required this.monday,
    required this.days,
    required this.good,
    required this.medium,
    required this.hard,
    required this.activeDays,
    required this.elapsedDays,
    required this.gutFeelingEntries,
    this.means,
  });

  /// The week's Monday, at midnight.
  final DateTime monday;

  /// Monday to Sunday, always 7.
  final List<ProgressDay> days;

  final int good;
  final int medium;
  final int hard;

  /// Days with any entry.
  final int activeDays;

  /// 7, or for the current week the days up to today.
  final int elapsedDays;

  final int gutFeelingEntries;

  /// The week's symptom means, only with
  /// [ProgressRules.minEntriesForMeans] entries on
  /// [ProgressRules.minDaysForMeans] days; otherwise null.
  final SymptomMeans? means;

  /// Days with a gut feeling.
  int get rated => good + medium + hard;

  @override
  bool operator ==(Object other) =>
      other is ProgressWeek &&
      other.monday == monday &&
      listEquals(other.days, days) &&
      other.good == good &&
      other.medium == medium &&
      other.hard == hard &&
      other.activeDays == activeDays &&
      other.elapsedDays == elapsedDays &&
      other.gutFeelingEntries == gutFeelingEntries &&
      other.means == means;

  @override
  int get hashCode => Object.hash(
    monday,
    Object.hashAll(days),
    good,
    medium,
    hard,
    activeDays,
    elapsedDays,
    gutFeelingEntries,
    means,
  );

  @override
  String toString() =>
      'ProgressWeek($monday, good: $good, medium: $medium, hard: $hard, '
      'active: $activeDays of $elapsedDays, entries: $gutFeelingEntries, '
      'means: $means)';
}

/// The last [ProgressRules.recentDays] local days, today included, for
/// „Für dich".
class RecentSignals {
  const RecentSignals({
    this.means,
    this.stress,
    required this.klo,
    required this.kloHard,
    required this.kloLoose,
  });

  /// The symptom means, with at least [ProgressRules.recentMinEntries]
  /// entries; otherwise null.
  final SymptomMeans? means;

  /// The stress mean of the entries with a stress value, with at least
  /// [ProgressRules.recentMinEntries] of them; otherwise null.
  final double? stress;

  /// Klo entries.
  final int klo;

  /// Klo entries with stool type 1–2.
  final int kloHard;

  /// Klo entries with stool type 4–5.
  final int kloLoose;

  @override
  bool operator ==(Object other) =>
      other is RecentSignals &&
      other.means == means &&
      other.stress == stress &&
      other.klo == klo &&
      other.kloHard == kloHard &&
      other.kloLoose == kloLoose;

  @override
  int get hashCode => Object.hash(means, stress, klo, kloHard, kloLoose);

  @override
  String toString() =>
      'RecentSignals(means: $means, stress: $stress, klo: $klo, '
      'hard: $kloHard, loose: $kloLoose)';
}

/// „Dein Verlauf": the last [ProgressRules.weeks] Monday weeks.
class Progress {
  const Progress({
    required this.weeks,
    required this.good,
    required this.medium,
    required this.hard,
    required this.activeDays,
    required this.elapsedDays,
    required this.longestStreak,
    required this.recent,
  });

  /// Oldest first; the last is the current week.
  final List<ProgressWeek> weeks;

  final int good;
  final int medium;
  final int hard;

  /// Days with any entry in the window …
  final int activeDays;

  /// … of this many days up to today.
  final int elapsedDays;

  /// The longest run of days in the window that are active or saved.
  final int longestStreak;

  final RecentSignals recent;

  /// No entry at all in the window.
  bool get isEmpty => activeDays == 0;

  /// At least [ProgressRules.minTrendWeeks] weeks have symptom means.
  bool get showTrend =>
      weeks.where((w) => w.means != null).length >= ProgressRules.minTrendWeeks;

  /// The last complete week had more good days than the one before, both
  /// with at least [ProgressRules.minRatedForComparison] rated days.
  bool get moreGoodDaysLastWeek {
    if (weeks.length < 3) return false;
    final last = weeks[weeks.length - 2];
    final before = weeks[weeks.length - 3];
    return last.rated >= ProgressRules.minRatedForComparison &&
        before.rated >= ProgressRules.minRatedForComparison &&
        last.good > before.good;
  }

  @override
  bool operator ==(Object other) =>
      other is Progress &&
      listEquals(other.weeks, weeks) &&
      other.good == good &&
      other.medium == medium &&
      other.hard == hard &&
      other.activeDays == activeDays &&
      other.elapsedDays == elapsedDays &&
      other.longestStreak == longestStreak &&
      other.recent == recent;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(weeks),
    good,
    medium,
    hard,
    activeDays,
    elapsedDays,
    longestStreak,
    recent,
  );

  @override
  String toString() =>
      'Progress(good: $good, medium: $medium, hard: $hard, '
      'active: $activeDays of $elapsedDays, longest: $longestStreak, '
      'recent: $recent, weeks: $weeks)';
}
