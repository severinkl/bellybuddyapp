import 'dart:math' as math;

import '../../models/gut_feeling_entry.dart';
import '../../models/insight_progress.dart';
import '../../models/insight_rules.dart';
import '../../models/insight_source.dart';
import '../../models/insights.dart';
import '../../utils/date_format_utils.dart';
import '../../utils/gut_feeling_rating.dart';

/// What the last [InsightRules.windowDays] local days of [source] show,
/// as of [now]; every threshold comes from [InsightRules].
///
/// - The window is [now]'s local day and the 29 before it, from local
///   midnight to the end of today: an entry logged for later today (the
///   trackers allow any time today) counts at once; anything after today is
///   ignored. So the result depends only on [now]'s day.
/// - A day's class comes from the mean of its gut-feeling entries' scores
///   (`gutFeelingScore`: the worst gut symptom; the mood never counts),
///   mapped with `gutFeelingLevelFor`: hard = „Schlecht", good = „Gut" or
///   „Sehr gut".
/// - For each good and hard day, the meals in the 24 h before its first
///   entry of that class (`[anchor − 24 h, anchor)`) say which ingredients
///   were there. Names match trimmed and case-insensitively, and each
///   ingredient counts once per day.
/// - The calm-day ingredients are those of every meal on a window day
///   without an entry that is „Schlecht" on its own (days without entries
///   count).
///
/// The journey holds the latest [InsightRules.daysNeeded] days with any
/// entry, from the same active-day set as the progress.
///
/// Pure: no I/O and no clock.
Insights computeInsights(InsightSource source, DateTime now) {
  final start = addDays(startOfDay(now.toLocal()), 1 - InsightRules.windowDays);
  final end = addDays(start, InsightRules.windowDays);
  bool inWindow(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  final gutFeelings = [
    for (final e in source.gutFeelings)
      if (inWindow(e.trackedAt)) e,
  ]..sort((a, b) => a.trackedAt.compareTo(b.trackedAt));
  final entriesByDay = <DateTime, List<GutFeelingEntry>>{};
  for (final e in gutFeelings) {
    entriesByDay.putIfAbsent(_localDay(e.trackedAt), () => []).add(e);
  }

  final calendar = <InsightDay>[];
  final hardAnchors = <DateTime>[];
  final goodAnchors = <DateTime>[];
  for (var i = 0; i < InsightRules.windowDays; i++) {
    final day = addDays(start, i);
    final entries = entriesByDay[day];
    final dayClass = entries == null ? DayClass.none : _dayClassOf(entries);
    calendar.add(InsightDay(day: day, dayClass: dayClass));
    final anchors = switch (dayClass) {
      DayClass.hard => hardAnchors,
      DayClass.good => goodAnchors,
      DayClass.medium || DayClass.none => null,
    };
    if (anchors != null) {
      // The anchor is the day's first entry in the day's class; a mean is
      // in a class only if at least one of its entries is too.
      anchors.add(
        entries!.firstWhere((e) => _entryClassOf(e) == dayClass).trackedAt,
      );
    }
  }

  final meals = [
    for (final m in source.meals)
      if (m.trackedAt.isBefore(end)) _Meal.of(m),
  ];
  final names = _displayNames(meals);
  final hardCounts = _daysThere(meals, hardAnchors);
  final goodCounts = _daysThere(meals, goodAnchors);

  final hardEntryDays = {
    for (final e in gutFeelings)
      if (_entryClassOf(e) == DayClass.hard) _localDay(e.trackedAt),
  };
  final calmDayIngredients = {
    for (final m in meals)
      if (inWindow(m.trackedAt) &&
          !hardEntryDays.contains(_localDay(m.trackedAt)))
        ...m.spellings.keys,
  };

  final hardDays = _column(hardCounts, hardAnchors.length, names);
  final goodDays = _column(goodCounts, goodAnchors.length, names);
  final noticed = _noticed(
    hardCounts,
    goodCounts,
    hardDays: hardAnchors.length,
    goodDays: goodAnchors.length,
    names: names,
  );

  final activeDays = {
    for (final t in source.activityTimes)
      if (inWindow(t)) _localDay(t),
  };
  final sortedDays = activeDays.toList()..sort();
  final journeyDays = sortedDays.skip(
    math.max(0, sortedDays.length - InsightRules.daysNeeded),
  );

  return Insights(
    progress: InsightProgress(
      activeDays: activeDays.length,
      gutFeelingEntries: gutFeelings.length,
    ),
    calendar: List.unmodifiable(calendar),
    goodDays: goodDays,
    hardDays: hardDays,
    noticed: List.unmodifiable(noticed),
    pick: _pick(noticed, goodDays),
    journey: List.unmodifiable([
      for (final day in journeyDays)
        JourneyDay(day, gutFeeling: entriesByDay.containsKey(day)),
    ]),
    calmDayIngredients: Set.unmodifiable(calmDayIngredients),
  );
}

/// Home's card: the top shown „Fällt mir auf" item, else the good days when
/// their column has items, else nothing yet.
InsightPick _pick(List<Noticed> noticed, DayColumn goodDays) {
  if (noticed.isNotEmpty && !noticed.first.uncertain) {
    return NoticedPick(noticed.first);
  }
  if (goodDays.shown && goodDays.often.isNotEmpty) {
    return GoodDaysPick(goodDays);
  }
  return const NothingYetPick();
}

DateTime _localDay(DateTime t) => startOfDay(t);

DayClass _classOf(GutFeelingRatingLevel level) => switch (level) {
  GutFeelingRatingLevel.spiGut || GutFeelingRatingLevel.gut => DayClass.good,
  GutFeelingRatingLevel.mittel => DayClass.medium,
  GutFeelingRatingLevel.schlecht => DayClass.hard,
};

/// The class of one entry on its own, from its [gutFeelingScore].
DayClass _entryClassOf(GutFeelingEntry entry) =>
    _classOf(gutFeelingLevelFor(gutFeelingScore(entry)));

/// The class of a day with [entries] (at least one), from the mean of their
/// [gutFeelingScore]s.
///
/// Exact at the half-step thresholds: the mean is one division of two whole
/// numbers, rounded once, and a mean that is not on a half step is at least
/// `1 / (2 · count)` away from it, far more than that rounding can move it.
DayClass _dayClassOf(List<GutFeelingEntry> entries) {
  var sum = 0;
  for (final e in entries) {
    sum += gutFeelingScore(e);
  }
  return _classOf(gutFeelingLevelFor(sum / entries.length));
}

/// A meal reduced to what the insights match on.
class _Meal {
  _Meal(this.trackedAt, this.spellings);

  factory _Meal.of(InsightMeal meal) {
    final spellings = <String, String>{};
    for (final raw in meal.ingredients) {
      final name = raw.trim();
      if (name.isNotEmpty) {
        spellings.putIfAbsent(name.toLowerCase(), () => name);
      }
    }
    return _Meal(meal.trackedAt, spellings);
  }

  final DateTime trackedAt;

  /// The trimmed spelling per ingredient key (trimmed, lower case); one
  /// entry per key, so a meal never counts an ingredient twice.
  final Map<String, String> spellings;
}

/// Per ingredient key, the trimmed spelling from the most recent meal that
/// lists it (the first such meal on equal times).
Map<String, String> _displayNames(List<_Meal> meals) {
  final names = <String, String>{};
  final namedAt = <String, DateTime>{};
  for (final meal in meals) {
    for (final MapEntry(key: key, value: name) in meal.spellings.entries) {
      final at = namedAt[key];
      if (at == null || meal.trackedAt.isAfter(at)) {
        names[key] = name;
        namedAt[key] = meal.trackedAt;
      }
    }
  }
  return names;
}

/// Per ingredient key, on how many of the days with [anchors] any meal in
/// the window `[anchor − 24 h, anchor)` listed it.
Map<String, int> _daysThere(List<_Meal> meals, List<DateTime> anchors) {
  final counts = <String, int>{};
  for (final anchor in anchors) {
    final from = anchor.subtract(InsightRules.mealsBefore);
    final there = {
      for (final m in meals)
        if (!m.trackedAt.isBefore(from) && m.trackedAt.isBefore(anchor))
          ...m.spellings.keys,
    };
    for (final key in there) {
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  return counts;
}

/// The column of [days] days: ingredients there on at least
/// [InsightRules.minOftenCount] and [InsightRules.minOftenShare] of them,
/// by count, then by name.
DayColumn _column(
  Map<String, int> counts,
  int days,
  Map<String, String> names,
) {
  if (days < InsightRules.minColumnDays) return DayColumn(days: days);
  final often = [
    for (final e in counts.entries)
      if (e.value >= InsightRules.minOftenCount &&
          _reaches(e.value, days, InsightRules.minOftenShare))
        e,
  ]..sort((a, b) => _higherFirstThenName(a.value, b.value, a.key, b.key));
  return DayColumn(
    days: days,
    often: List.unmodifiable([
      for (final e in often.take(InsightRules.maxOften))
        IngredientCount(names[e.key]!, e.value, of: days),
    ]),
  );
}

/// An ingredient that passes the „Fällt mir auf" rates; [gap] is the
/// numerator over the denominator all candidates share.
typedef _Candidate = ({String key, int hard, int good, int gap});

/// „Fällt mir auf", in whole numbers so the thresholds hold exactly:
/// `rate = hard/H ≥` [InsightRules.minHardShare] and
/// `gap = rate − (G > 0 ? good/G : 0) ≥` [InsightRules.minShareGap]. The
/// gap is kept as its numerator over the denominator shared by every
/// ingredient (`H·G`, or `H` while `G == 0`), which also sorts it exactly.
List<Noticed> _noticed(
  Map<String, int> hardCounts,
  Map<String, int> goodCounts, {
  required int hardDays,
  required int goodDays,
  required Map<String, String> names,
}) {
  if (hardDays < InsightRules.minHardDays) return const [];
  final denominator = goodDays > 0 ? hardDays * goodDays : hardDays;
  final candidates = <_Candidate>[];
  for (final MapEntry(key: key, value: hard) in hardCounts.entries) {
    final good = goodCounts[key] ?? 0;
    final gap = goodDays > 0 ? hard * goodDays - good * hardDays : hard;
    if (_reaches(hard, hardDays, InsightRules.minHardShare) &&
        _reaches(gap, denominator, InsightRules.minShareGap)) {
      candidates.add((key: key, hard: hard, good: good, gap: gap));
    }
  }
  candidates.sort(
    (a, b) => a.hard != b.hard
        ? b.hard - a.hard
        : _higherFirstThenName(a.gap, b.gap, a.key, b.key),
  );

  Noticed toNoticed(_Candidate c, {required bool uncertain}) => Noticed(
    name: names[c.key]!,
    hard: c.hard,
    hardDays: hardDays,
    good: c.good,
    goodDays: goodDays,
    uncertain: uncertain,
  );
  final shown = candidates.where((c) => c.hard >= InsightRules.minNoticedHard);
  final uncertain = candidates.where(
    (c) => c.hard == InsightRules.uncertainHard,
  );
  return [
    for (final c in shown.take(InsightRules.maxNoticed))
      toNoticed(c, uncertain: false),
    for (final c in uncertain.take(InsightRules.maxUncertain))
      toNoticed(c, uncertain: true),
  ];
}

/// Whether [count] of [of] is at least [share], exactly.
bool _reaches(int count, int of, InsightShare share) =>
    count * share.denominator >= of * share.numerator;

/// The higher of [a] and [b] first, then by key (the name without case) in
/// German order ([_germanOrder]).
int _higherFirstThenName(int a, int b, String keyA, String keyB) =>
    a != b ? b - a : _germanOrder(keyA, keyB);

/// Lower-case keys in German dictionary order (DIN 5007-1): ä, ö, ü as a,
/// o, u and ß as ss, so „Äpfel" sorts with the A's, not after „Zwiebel".
/// Keys equal that way (e.g. „masse", „maße") fall back to their code
/// units, so the order stays total and the same whatever the input order.
int _germanOrder(String keyA, String keyB) {
  final folded = _foldUmlauts(keyA).compareTo(_foldUmlauts(keyB));
  return folded != 0 ? folded : keyA.compareTo(keyB);
}

String _foldUmlauts(String key) => key
    .replaceAll('ä', 'a')
    .replaceAll('ö', 'o')
    .replaceAll('ü', 'u')
    .replaceAll('ß', 'ss');
