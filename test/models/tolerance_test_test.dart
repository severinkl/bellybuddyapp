import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/models/pattern_stats.dart';
import 'package:belly_buddy/models/tolerance_test.dart';

Map<String, dynamic> _stats(Map<String, dynamic> extra) => {
  'window_days': 90,
  'rated_days': 41,
  'hard_days': 9,
  'ready': true,
  'groups': <Object>[],
  'ingredients': <Object>[],
  'calm': <Object>[],
  'restrictive': false,
  ...extra,
};

Map<String, dynamic> _tested(String key, String outcome, String endedOn) => {
  'kind': 'ingredient',
  'key': key,
  'name': key,
  'outcome': outcome,
  'ended_on': endedOn,
};

void main() {
  test('parses the §5.2 test, tested, proposal and restrictive', () {
    final stats = PatternStats.fromJson(
      _stats({
        'test': {
          'id': 't1',
          'kind': 'ingredient',
          'key': 'zwiebel',
          'name': 'Zwiebel',
          'origin': 'proposed',
          'status': 'active',
          'phase': 'leave_out',
          'starts_on': '2026-12-02',
          'leave_out_days': 5,
          'reintro_days': 3,
          'day_index': 2,
          'days': [
            {
              'day': '2026-12-02',
              'phase': 'leave_out',
              'class': 'good',
              'exposed': false,
            },
            {
              'day': '2026-12-03',
              'phase': 'leave_out',
              'class': 'none',
              'exposed': true,
            },
          ],
          'result': {
            'without': {'good': 4, 'counted': 5},
            'with': {'good': 1, 'counted': 3},
            'outcome': 'worse',
            'not_kept': 1,
            'not_eaten': 2,
          },
        },
        'tested': [_tested('zwiebel', 'slightly_worse', '2026-12-10')],
        'proposal': {'kind': 'group', 'key': 'fructans', 'name': 'Fruktane'},
        'restrictive': true,
      }),
    );

    final t = stats.test!;
    expect(t.id, 't1');
    expect(t.subject, const TestSubject('ingredient', 'zwiebel', 'Zwiebel'));
    expect(t.origin, 'proposed');
    expect(t.status, 'active');
    expect(t.isActive, isTrue);
    expect(t.phase, TestPhase.leaveOut);
    expect(t.startsOn, DateTime(2026, 12, 2));
    expect(t.leaveOutDays, 5);
    expect(t.reintroDays, 3);
    expect(t.dayIndex, 2);
    expect(t.days, hasLength(2));
    expect(t.days[0].day, DateTime(2026, 12, 2));
    expect(t.days[0].phase, TestPhase.leaveOut);
    expect(t.days[0].dayClass, DayClass.good);
    expect(t.days[0].exposed, isFalse);
    expect(t.days[1].dayClass, DayClass.none);
    expect(t.days[1].exposed, isTrue);
    final r = t.result!;
    expect(r.goodWithout, 4);
    expect(r.countedWithout, 5);
    expect(r.goodWith, 1);
    expect(r.countedWith, 3);
    expect(r.outcome, TestOutcome.worse);
    expect(r.notKept, 1);
    expect(r.notEaten, 2);

    expect(stats.tested, hasLength(1));
    expect(stats.tested.single.subject.key, 'zwiebel');
    expect(stats.tested.single.outcome, TestOutcome.slightlyWorse);
    expect(stats.tested.single.endedOn, DateTime(2026, 12, 10));
    expect(stats.proposal, const TestSubject('group', 'fructans', 'Fruktane'));
    expect(stats.restrictive, isTrue);
  });

  test('before starts_on, a null result and the phase-1 shape parse', () {
    final stats = PatternStats.fromJson(
      _stats({
        'test': {
          'id': 't1',
          'kind': 'group',
          'key': 'fructans',
          'name': 'Fruktane',
          'origin': 'picked',
          'status': 'active',
          'phase': 'leave_out',
          'starts_on': '2026-12-02',
          'leave_out_days': 5,
          'reintro_days': 3,
          'day_index': 0,
          'days': <Object>[],
          'result': null,
        },
      }),
    );
    expect(stats.test!.days, isEmpty);
    expect(stats.test!.result, isNull);
    expect(stats.tested, isEmpty);
    expect(stats.proposal, isNull);
    expect(stats.restrictive, isFalse);

    final phase1 = PatternStats.fromJson(_stats({}));
    expect(phase1.test, isNull);
    expect(phase1.tested, isEmpty);
  });

  test('every outcome and phase wire value maps', () {
    expect(TestOutcome.fromWire('worse'), TestOutcome.worse);
    expect(TestOutcome.fromWire('slightly_worse'), TestOutcome.slightlyWorse);
    expect(TestOutcome.fromWire('no_difference'), TestOutcome.noDifference);
    expect(TestOutcome.fromWire('better'), TestOutcome.better);
    expect(TestOutcome.fromWire('unclear'), TestOutcome.unclear);
    expect(TestOutcome.fromWire('nope'), isNull);
    expect(TestPhase.fromWire('leave_out'), TestPhase.leaveOut);
    expect(TestPhase.fromWire('reintro'), TestPhase.reintro);
    expect(TestPhase.fromWire('done'), TestPhase.done);
    expect(TestPhase.fromWire('later'), isNull);
  });

  test('an unknown tested outcome is dropped, the rest stays', () {
    final stats = PatternStats.fromJson(
      _stats({
        'tested': [
          _tested('zwiebel', 'mystery', '2026-12-10'),
          _tested('lauch', 'better', '2026-12-01'),
        ],
      }),
    );
    expect(stats.tested.map((t) => t.subject.key), ['lauch']);
  });

  test('reintroStartsOn and resultDay from startsOn and the lengths', () {
    final t = ToleranceTestView(
      id: 't1',
      subject: const TestSubject('ingredient', 'zwiebel', 'Zwiebel'),
      origin: 'picked',
      status: 'active',
      phase: TestPhase.leaveOut,
      // Across the end of October (DST in Europe): calendar days, no drift.
      startsOn: DateTime(2026, 10, 22),
      leaveOutDays: 5,
      reintroDays: 3,
      dayIndex: 0,
      days: const [],
    );
    expect(t.reintroStartsOn, DateTime(2026, 10, 27));
    expect(t.resultDay, DateTime(2026, 10, 30));
    expect(t.totalDays, 8);
  });

  test('testedFor returns the latest within 60 days, null after', () {
    final stats = PatternStats.fromJson(
      _stats({
        'tested': [
          _tested('zwiebel', 'worse', '2026-12-10'),
          _tested('lauch', 'better', '2026-12-05'),
          _tested('zwiebel', 'unclear', '2026-11-01'),
        ],
      }),
    );
    final today = DateTime(2026, 12, 20);
    final hit = stats.testedFor('ingredient', 'zwiebel', today: today);
    expect(hit?.outcome, TestOutcome.worse);
    expect(stats.testedFor('group', 'zwiebel', today: today), isNull);
    expect(stats.testedFor('ingredient', 'knoblauch', today: today), isNull);

    // Core's bound: age < 60. 2026-12-10 + 59 days = 2027-02-07 is in,
    // 2027-02-08 (age 60) is out.
    expect(
      stats.testedFor('ingredient', 'zwiebel', today: DateTime(2027, 2, 7)),
      isNotNull,
    );
    expect(
      stats.testedFor('ingredient', 'zwiebel', today: DateTime(2027, 2, 8)),
      isNull,
    );
  });

  test('a missing restrictive reads as restrictive (safety)', () {
    final j = _stats({})..remove('restrictive');
    expect(PatternStats.fromJson(j).restrictive, isTrue);
    expect(PatternStats.fromJson(_stats({})).restrictive, isFalse);
  });

  test('a tested value that is not a list is empty, the rest parses', () {
    final stats = PatternStats.fromJson(
      _stats({
        'tested': {'oops': true},
        'proposal': {'kind': 'group', 'key': 'fructans', 'name': 'Fruktane'},
      }),
    );
    expect(stats.tested, isEmpty);
    expect(stats.proposal?.key, 'fructans');
    expect(stats.ready, isTrue);
  });
}
