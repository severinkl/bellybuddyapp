import '../../models/gut_feeling_entry.dart';
import '../../models/insights.dart';
import '../../models/progress.dart';
import '../../models/progress_rules.dart';
import '../../utils/date_format_utils.dart';
import '../insights/day_class.dart';

/// „Dein Verlauf" of [source] as of [now]; every threshold comes from
/// [ProgressRules].
///
/// - The window is the Monday of [now]'s local week and the
///   [ProgressRules.weeks] − 1 weeks before it, to the end of today. Days
///   after today are `future` and never counted.
/// - An entry's day is the wall-clock date of its `trackedAt` (never
///   converted to local time).
/// - A day's class is the Muster's ([dayClassOf]); a day is active with an
///   entry of any table.
/// - The longest streak is the longest run of window days up to today that
///   are active or in [savedDays].
/// - The recent signals cover the last [ProgressRules.recentDays] days,
///   today included.
///
/// Pure: no I/O and no clock.
Progress computeProgress(
  ProgressSource source, {
  required DateTime now,
  Set<DateTime> savedDays = const {},
}) {
  final today = startOfDay(now.toLocal());
  final start = addDays(mondayOf(today), -7 * (ProgressRules.weeks - 1));

  final entriesByDay = <DateTime, List<GutFeelingEntry>>{};
  for (final e in source.gutFeelings) {
    entriesByDay.putIfAbsent(startOfDay(e.trackedAt), () => []).add(e);
  }
  final activeDays = {
    ...entriesByDay.keys,
    for (final t in source.toilets) startOfDay(t.trackedAt),
    for (final t in source.otherTimes) startOfDay(t),
  };
  final countedDays = {...activeDays, for (final d in savedDays) startOfDay(d)};

  final weeks = <ProgressWeek>[];
  var longestStreak = 0;
  var streak = 0;
  for (var w = 0; w < ProgressRules.weeks; w++) {
    final monday = addDays(start, 7 * w);
    final days = <ProgressDay>[];
    final weekEntries = <GutFeelingEntry>[];
    var daysWithEntries = 0;
    for (var i = 0; i < 7; i++) {
      final day = addDays(monday, i);
      final future = day.isAfter(today);
      final entries = future ? null : entriesByDay[day];
      if (entries != null) {
        weekEntries.addAll(entries);
        daysWithEntries++;
      }
      days.add(
        ProgressDay(
          day: day,
          dayClass: entries == null ? DayClass.none : dayClassOf(entries),
          active: !future && activeDays.contains(day),
          future: future,
        ),
      );
      if (!future) {
        streak = countedDays.contains(day) ? streak + 1 : 0;
        if (streak > longestStreak) longestStreak = streak;
      }
    }
    int count(DayClass c) => days.where((d) => d.dayClass == c).length;
    weeks.add(
      ProgressWeek(
        monday: monday,
        days: List.unmodifiable(days),
        good: count(DayClass.good),
        medium: count(DayClass.medium),
        hard: count(DayClass.hard),
        activeDays: days.where((d) => d.active).length,
        elapsedDays: days.where((d) => !d.future).length,
        gutFeelingEntries: weekEntries.length,
        means:
            weekEntries.length >= ProgressRules.minEntriesForMeans &&
                daysWithEntries >= ProgressRules.minDaysForMeans
            ? _means(weekEntries)
            : null,
      ),
    );
  }

  int total(int Function(ProgressWeek w) of) =>
      weeks.fold(0, (sum, w) => sum + of(w));
  return Progress(
    weeks: List.unmodifiable(weeks),
    good: total((w) => w.good),
    medium: total((w) => w.medium),
    hard: total((w) => w.hard),
    activeDays: total((w) => w.activeDays),
    elapsedDays: total((w) => w.elapsedDays),
    longestStreak: longestStreak,
    recent: _recent(source, entriesByDay, today),
  );
}

RecentSignals _recent(
  ProgressSource source,
  Map<DateTime, List<GutFeelingEntry>> entriesByDay,
  DateTime today,
) {
  final first = addDays(today, 1 - ProgressRules.recentDays);
  bool recent(DateTime day) => !day.isBefore(first) && !day.isAfter(today);

  final entries = [
    for (final MapEntry(key: day, value: list) in entriesByDay.entries)
      if (recent(day)) ...list,
  ];
  final stress = [for (final e in entries) ?e.stress];
  final stoolTypes = [
    for (final t in source.toilets)
      if (recent(startOfDay(t.trackedAt))) t.stoolType,
  ];
  return RecentSignals(
    means: entries.length >= ProgressRules.recentMinEntries
        ? _means(entries)
        : null,
    stress: stress.length >= ProgressRules.recentMinEntries
        ? _mean(stress)
        : null,
    klo: stoolTypes.length,
    kloHard: stoolTypes.where((s) => s >= 1 && s <= 2).length,
    kloLoose: stoolTypes.where((s) => s >= 4 && s <= 5).length,
  );
}

SymptomMeans _means(List<GutFeelingEntry> entries) => SymptomMeans(
  bloating: _mean([for (final e in entries) e.bloating]),
  gas: _mean([for (final e in entries) e.gas]),
  cramps: _mean([for (final e in entries) e.cramps]),
  fullness: _mean([for (final e in entries) e.fullness]),
);

double _mean(List<int> values) =>
    values.fold(0, (sum, v) => sum + v) / values.length;
