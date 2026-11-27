import '../utils/date_format_utils.dart';
import '../utils/json_values.dart';
import 'insights.dart';

/// Where a tolerance test stands (wire values of core's `pattern-stats`):
/// leaving the subject out, eating it again, or over.
enum TestPhase {
  leaveOut('leave_out'),
  reintro('reintro'),
  done('done');

  const TestPhase(this.wire);
  final String wire;

  /// The phase for a wire value; null for one this build does not know.
  static TestPhase? fromWire(Object? value) =>
      lookupWire(values, (p) => p.wire, value);

  /// The phase for a wire value; throws for one this build does not know.
  static TestPhase _require(Object? value) =>
      requireWire(values, (p) => p.wire, value, 'phase');
}

/// A finished test's outcome (spec §5.2). Always relative, never a verdict.
enum TestOutcome {
  worse('worse'),
  slightlyWorse('slightly_worse'),
  noDifference('no_difference'),
  better('better'),
  unclear('unclear');

  const TestOutcome(this.wire);
  final String wire;

  /// The outcome for a wire value; null for one this build does not know.
  static TestOutcome? fromWire(Object? value) =>
      lookupWire(values, (o) => o.wire, value);

  /// The outcome for a wire value; throws for one this build does not know.
  static TestOutcome _require(Object? value) =>
      requireWire(values, (o) => o.wire, value, 'outcome');
}

/// What a test is about: a FODMAP group or an ingredient.
class TestSubject {
  const TestSubject(this.kind, this.key, this.name);

  /// `group` or `ingredient`.
  final String kind;

  /// The engine key, verbatim from the stats item (a FODMAP key for a
  /// group); sent back as is when starting a test.
  final String key;

  /// The display name.
  final String name;

  factory TestSubject.fromJson(Map<String, dynamic> j) =>
      TestSubject(j['kind'] as String, j['key'] as String, j['name'] as String);

  @override
  bool operator ==(Object other) =>
      other is TestSubject &&
      other.kind == kind &&
      other.key == key &&
      other.name == name;

  @override
  int get hashCode => Object.hash(kind, key, name);

  @override
  String toString() => 'TestSubject($kind, $key)';
}

/// A `yyyy-MM-dd` wire date as the local wall-clock day, at midnight (as
/// `todayProvider`); never converted from or to UTC.
DateTime _day(Object? raw) => startOfDay(DateTime.parse(raw as String));

/// One day of a test: its phase, how it went and whether the subject was
/// eaten (in the day's exposure window).
class TestDayView {
  const TestDayView({
    required this.day,
    required this.phase,
    required this.dayClass,
    required this.exposed,
  });

  final DateTime day;
  final TestPhase phase;

  /// [DayClass.none] for a day without gut-feeling entry („kein Eintrag").
  final DayClass dayClass;
  final bool exposed;

  /// Throws on a missing field or an unknown phase or class.
  factory TestDayView.fromJson(Map<String, dynamic> j) {
    final phase = TestPhase._require(j['phase']);
    final cls = requireWire(
      DayClass.values,
      (c) => c.name,
      j['class'],
      'class',
    );
    return TestDayView(
      day: _day(j['day']),
      phase: phase,
      dayClass: cls,
      exposed: j['exposed'] as bool,
    );
  }
}

/// The comparison once the phases are over (spec §5.2): good days among the
/// counted ones, without and with the subject.
class TestResult {
  const TestResult({
    required this.goodWithout,
    required this.countedWithout,
    required this.goodWith,
    required this.countedWith,
    required this.outcome,
    this.notKept = 0,
    this.notEaten = 0,
  });

  final int goodWithout;
  final int countedWithout;
  final int goodWith;
  final int countedWith;
  final TestOutcome outcome;

  /// Leave-out days on which the subject was eaten („nicht eingehalten").
  final int notKept;

  /// Rated reintroduction days without it („nicht gegessen").
  final int notEaten;

  /// Throws on a missing field or an unknown outcome.
  factory TestResult.fromJson(Map<String, dynamic> j) {
    final outcome = TestOutcome._require(j['outcome']);
    final without = j['without'] as Map<String, dynamic>;
    final with_ = j['with'] as Map<String, dynamic>;
    return TestResult(
      goodWithout: without['good'] as int,
      countedWithout: without['counted'] as int,
      goodWith: with_['good'] as int,
      countedWith: with_['counted'] as int,
      outcome: outcome,
      notKept: j['not_kept'] as int,
      notEaten: j['not_eaten'] as int,
    );
  }
}

/// The user's current test (active, or completed within 14 days) as core
/// evaluates it. The server never writes: an `active` test with
/// [TestPhase.done] is over and the app completes it.
class ToleranceTestView {
  const ToleranceTestView({
    required this.id,
    required this.subject,
    required this.origin,
    required this.status,
    required this.phase,
    required this.startsOn,
    required this.leaveOutDays,
    required this.reintroDays,
    required this.dayIndex,
    required this.days,
    this.result,
  });

  /// The server's default lengths (core inserts them; the app sends none).
  static const defaultLeaveOutDays = 5;
  static const defaultReintroDays = 3;

  final String id;
  final TestSubject subject;

  /// `proposed` or `picked`.
  final String origin;

  /// `active`, `completed` or `stopped`.
  final String status;
  final TestPhase phase;

  /// The first leave-out day (local wall-clock date, at midnight).
  final DateTime startsOn;
  final int leaveOutDays;
  final int reintroDays;

  /// 1-based day of the test; 0 before [startsOn].
  final int dayIndex;

  /// The test's days so far (empty before [startsOn]).
  final List<TestDayView> days;
  final TestResult? result;

  bool get isActive => status == 'active';

  int get totalDays => leaveOutDays + reintroDays;

  /// The first reintroduction day.
  DateTime get reintroStartsOn => addDays(startsOn, leaveOutDays);

  /// The day after the last test day: the result is there.
  DateTime get resultDay => addDays(startsOn, totalDays);

  /// Throws on a missing field or an unknown wire value.
  factory ToleranceTestView.fromJson(Map<String, dynamic> j) {
    final phase = TestPhase._require(j['phase']);
    final result = j['result'];
    return ToleranceTestView(
      id: j['id'] as String,
      subject: TestSubject.fromJson(j),
      origin: j['origin'] as String,
      status: j['status'] as String,
      phase: phase,
      startsOn: _day(j['starts_on']),
      leaveOutDays: j['leave_out_days'] as int,
      reintroDays: j['reintro_days'] as int,
      dayIndex: j['day_index'] as int,
      days: [
        for (final d in (j['days'] as List?) ?? const [])
          TestDayView.fromJson(d as Map<String, dynamic>),
      ],
      result: result == null
          ? null
          : TestResult.fromJson(result as Map<String, dynamic>),
    );
  }
}

/// A completed test of the last 180 days.
class TestedItem {
  const TestedItem({
    required this.subject,
    required this.outcome,
    required this.endedOn,
  });

  final TestSubject subject;
  final TestOutcome outcome;

  /// The local day it ended.
  final DateTime endedOn;

  /// Throws on a missing field or an unknown outcome.
  factory TestedItem.fromJson(Map<String, dynamic> j) {
    final outcome = TestOutcome._require(j['outcome']);
    return TestedItem(
      subject: TestSubject.fromJson(j),
      outcome: outcome,
      endedOn: _day(j['ended_on']),
    );
  }
}
