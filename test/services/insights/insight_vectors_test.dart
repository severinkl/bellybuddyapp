import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/models/insight_rules.dart';
import 'package:belly_buddy/models/insight_source.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/services/insights/insights_engine.dart';
import 'package:belly_buddy/utils/date_format_utils.dart';
import 'package:belly_buddy/utils/wall_clock.dart';

/// Core's shared vectors (`backend/tests/fixtures/insights/vectors.json`,
/// copied byte for byte): the Dart engine and core's Python port must give
/// exactly these results. Run under `TZ=Europe/Vienna`.
final bool _vienna =
    DateTime(2026, 1, 15).timeZoneOffset == const Duration(hours: 1) &&
    DateTime(2026, 7, 15).timeZoneOffset == const Duration(hours: 2);

Map<String, dynamic> _noticedJson(Noticed n) => {
  'name': n.name,
  'hard': n.hard,
  'hard_days': n.hardDays,
  'good': n.good,
  'good_days': n.goodDays,
  'uncertain': n.uncertain,
};

Map<String, dynamic> _columnJson(DayColumn c) => {
  'days': c.days,
  'shown': c.shown,
  'often': [
    for (final o in c.often) {'name': o.name, 'count': o.count, 'of': o.of},
  ],
};

/// Insights in the vectors' JSON shape. [Insights.calmDayIngredients] and
/// [Insights.unlocked] are Dart-only, not in the vectors, so not compared
/// (`progress.unlocked` is).
Map<String, dynamic> _toJson(Insights i) => {
  'progress': {
    'active_days': i.progress.activeDays,
    'gut_feeling_entries': i.progress.gutFeelingEntries,
    'unlocked': i.progress.unlocked,
  },
  'calendar': {
    'first_day': formatIsoDate(i.calendar.first.day),
    'last_day': formatIsoDate(i.calendar.last.day),
    'classes': {
      for (final d in i.calendar)
        if (d.dayClass != DayClass.none) formatIsoDate(d.day): d.dayClass.name,
    },
  },
  'gut_feeling_days': i.gutFeelingDays,
  'good_days': _columnJson(i.goodDays),
  'hard_days': _columnJson(i.hardDays),
  'show_noticed': i.showNoticed,
  'noticed': [for (final n in i.noticed) _noticedJson(n)],
  'pick': switch (i.pick) {
    NoticedPick(:final noticed) => {
      'kind': 'noticed',
      'noticed': _noticedJson(noticed),
    },
    GoodDaysPick() => {'kind': 'good_days'},
    NothingYetPick() => {'kind': 'nothing_yet'},
  },
  'journey': [
    for (final j in i.journey)
      {'day': formatIsoDate(j.day), 'gut_feeling': j.gutFeeling},
  ],
};

InsightSource _source(Map<String, dynamic> v) => InsightSource(
  meals: [
    for (final m in v['meals'] as List)
      InsightMeal(
        trackedAt: wallClockFromWire(m['tracked_at'] as String),
        ingredients: List<String>.from(m['ingredients'] as List),
      ),
  ],
  gutFeelings: [
    for (final (i, g) in (v['gut_feelings'] as List).indexed)
      GutFeelingEntry(
        id: 'g$i',
        trackedAt: wallClockFromWire(g['tracked_at'] as String),
        bloating: g['bloating'] as int,
        gas: g['gas'] as int,
        cramps: g['cramps'] as int,
        fullness: g['fullness'] as int,
        stress: g['stress'] as int?,
        happiness: g['happiness'] as int?,
        energy: g['energy'] as int?,
        focus: g['focus'] as int?,
        bodyFeel: g['body_feel'] as int?,
      ),
  ],
  activityTimes: [
    for (final a in v['activity'] as List) wallClockFromWire(a as String),
  ],
);

void main() {
  final file =
      jsonDecode(File('test/fixtures/insights/vectors.json').readAsStringSync())
          as Map<String, dynamic>;
  final vectors = (file['vectors'] as List).cast<Map<String, dynamic>>();

  test('the file holds core\'s format', () {
    expect(file['timezone'], 'Europe/Vienna');
    expect(vectors.length, greaterThanOrEqualTo(28));
    final ids = vectors.map((v) => v['id']).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('the rules table matches InsightRules', () {
    List<int> share(InsightShare s) => [s.numerator, s.denominator];
    expect(file['rules'], {
      'window_days': InsightRules.windowDays,
      'days_needed': InsightRules.daysNeeded,
      'gut_feelings_needed': InsightRules.gutFeelingsNeeded,
      'meals_before_hours': InsightRules.mealsBefore.inHours,
      'min_column_days': InsightRules.minColumnDays,
      'min_often_count': InsightRules.minOftenCount,
      'min_often_share': share(InsightRules.minOftenShare),
      'max_often': InsightRules.maxOften,
      'min_hard_days': InsightRules.minHardDays,
      'min_hard_share': share(InsightRules.minHardShare),
      'min_share_gap': share(InsightRules.minShareGap),
      'min_noticed_hard': InsightRules.minNoticedHard,
      'uncertain_hard': InsightRules.uncertainHard,
      'max_noticed': InsightRules.maxNoticed,
      'max_uncertain': InsightRules.maxUncertain,
    });
  });

  for (final v in vectors) {
    test(v['id'] as String, () {
      final got = computeInsights(
        _source(v),
        DateTime.parse(v['now'] as String),
      );
      expect(
        jsonDecode(jsonEncode(_toJson(got))),
        v['expected'],
        reason: v['description'] as String,
      );
    }, skip: _vienna ? false : 'only under TZ=Europe/Vienna');
  }
}
