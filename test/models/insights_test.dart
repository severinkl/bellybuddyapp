import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/insight_rules.dart';
import 'package:belly_buddy/models/insight_source.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/services/insights/insights_engine.dart';

final _now = DateTime(2026, 11, 23, 20);

GutFeelingEntry _gut(int day, int v) => GutFeelingEntry(
  id: 'g$day',
  trackedAt: DateTime(2026, 11, day, 12),
  bloating: v,
  gas: v,
  cramps: v,
  fullness: v,
);

/// Four hard days after Zwiebel and Reis, four good ones after Reis: every
/// part of the insights is filled. Built anew on every call.
InsightSource _source() => InsightSource(
  meals: [
    for (var d = 1; d <= 4; d++)
      InsightMeal(
        trackedAt: DateTime(2026, 11, d, 8),
        ingredients: ['Zwiebel', 'Reis'],
      ),
    for (var d = 10; d <= 13; d++)
      InsightMeal(trackedAt: DateTime(2026, 11, d, 8), ingredients: ['Reis']),
  ],
  gutFeelings: [
    for (var d = 1; d <= 4; d++) _gut(d, 5),
    for (var d = 10; d <= 13; d++) _gut(d, 1),
  ],
  activityTimes: [for (var d = 1; d <= 13; d++) DateTime(2026, 11, d, 12)],
);

Insights _with(
  Insights i, {
  InsightProgress? progress,
  List<InsightDay>? calendar,
  DayColumn? goodDays,
  DayColumn? hardDays,
  List<Noticed>? noticed,
  InsightPick? pick,
  List<JourneyDay>? journey,
  Set<String>? calmDayIngredients,
}) => Insights(
  progress: progress ?? i.progress,
  calendar: calendar ?? i.calendar,
  goodDays: goodDays ?? i.goodDays,
  hardDays: hardDays ?? i.hardDays,
  noticed: noticed ?? i.noticed,
  pick: pick ?? i.pick,
  journey: journey ?? i.journey,
  calmDayIngredients: calmDayIngredients ?? i.calmDayIngredients,
);

void main() {
  final insights = computeInsights(_source(), _now);

  test('the sample fills every part', () {
    expect(insights.unlocked, isTrue);
    expect(insights.goodDays.often, isNotEmpty);
    expect(insights.hardDays.often, isNotEmpty);
    expect(insights.noticed, isNotEmpty);
    expect(insights.pick, isA<NoticedPick>());
    expect(insights.calmDayIngredients, {'reis'});
  });

  test('„Fällt mir auf" shows from the minimum of hard days on', () {
    const minimum = InsightRules.minHardDays;
    expect(
      _with(insights, hardDays: const DayColumn(days: minimum)).showNoticed,
      isTrue,
    );
    expect(
      _with(insights, hardDays: const DayColumn(days: minimum - 1)).showNoticed,
      isFalse,
    );
  });

  test('computed again from equal entries: equal, with an equal hash code '
      '(a refetch with nothing new rebuilds nothing)', () {
    final again = computeInsights(_source(), _now);

    expect(identical(again, insights), isFalse);
    expect(again, insights);
    expect(again.hashCode, insights.hashCode);
  });

  test('any difference makes them unequal', () {
    final last = insights.calendar.last;
    final variants = {
      'progress': _with(
        insights,
        progress: InsightProgress(
          activeDays: insights.progress.activeDays + 1,
          gutFeelingEntries: insights.progress.gutFeelingEntries,
        ),
      ),
      'a calendar day': _with(
        insights,
        calendar: [
          ...insights.calendar.take(insights.calendar.length - 1),
          InsightDay(day: last.day, dayClass: DayClass.hard),
        ],
      ),
      'the good days': _with(
        insights,
        goodDays: DayColumn(days: insights.goodDays.days),
      ),
      'the hard days': _with(
        insights,
        hardDays: DayColumn(
          days: insights.hardDays.days + 1,
          often: insights.hardDays.often,
        ),
      ),
      'what I noticed': _with(insights, noticed: const []),
      'the pick': _with(insights, pick: const NothingYetPick()),
      'the journey': _with(
        insights,
        journey: [JourneyDay(DateTime(2026, 11, 23), gutFeeling: true)],
      ),
      'the calm-day ingredients': _with(
        insights,
        calmDayIngredients: {'reis', 'zwiebel'},
      ),
    };
    for (final MapEntry(key: part, value: changed) in variants.entries) {
      expect(changed, isNot(insights), reason: part);
    }
  });

  test('calm-day ingredients compare as a set', () {
    final ab = _with(insights, calmDayIngredients: {'a', 'b'});
    final ba = _with(insights, calmDayIngredients: {'b', 'a'});

    expect(ab, ba);
    expect(ab.hashCode, ba.hashCode);
  });
}
