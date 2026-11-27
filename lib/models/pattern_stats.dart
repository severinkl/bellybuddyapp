import '../utils/date_format_utils.dart';
import '../utils/json_values.dart';
import 'tolerance_test.dart';

/// How noticeable a food or FODMAP group is in the pattern comparison
/// (wire values of core's `pattern-stats`). Always relative, never a verdict.
enum StatLevel {
  strong,
  noticed,
  unsure,
  calm;

  /// The level for a wire value; null for one this build does not know.
  static StatLevel? fromWire(Object? value) =>
      lookupWire(values, (l) => l.name, value);
}

/// One row of the comparison: a group or an ingredient, with how often a
/// hard day followed with and without it.
class StatItem {
  const StatItem({
    required this.kind,
    required this.key,
    required this.name,
    required this.level,
    required this.exposed,
    required this.exposedHard,
    required this.unexposed,
    required this.unexposedHard,
    this.groups = const [],
    this.nestedIn,
  });

  final String kind;

  /// The engine key (trimmed, lower case); sent back verbatim by the app.
  final String key;
  final String name;
  final StatLevel level;
  final int exposed;
  final int exposedHard;
  final int unexposed;
  final int unexposedHard;
  final List<String> groups;
  final String? nestedIn;

  /// Throws when a field is missing or of the wrong type, or the level is
  /// unknown (the caller drops such items, see [PatternStats.fromJson]).
  factory StatItem.fromJson(Map<String, dynamic> j) {
    final level = requireWire(
      StatLevel.values,
      (l) => l.name,
      j['level'],
      'level',
    );
    return StatItem(
      kind: j['kind'] as String,
      key: j['key'] as String,
      name: j['name'] as String,
      level: level,
      exposed: j['exposed'] as int,
      exposedHard: j['exposed_hard'] as int,
      unexposed: j['unexposed'] as int,
      unexposedHard: j['unexposed_hard'] as int,
      groups: [...?(j['groups'] as List?)?.cast<String>()],
      nestedIn: j['nested_in'] as String?,
    );
  }
}

/// The 90-day pattern comparison from core's `pattern-stats` route.
class PatternStats {
  const PatternStats({
    required this.windowDays,
    required this.ratedDays,
    required this.hardDays,
    required this.ready,
    this.groups = const [],
    this.ingredients = const [],
    this.calm = const [],
    this.test,
    this.tested = const [],
    this.proposal,
    this.restrictive = false,
    this.hasUnreadableTest = false,
  });

  final int windowDays;
  final int ratedDays;
  final int hardDays;
  final bool ready;
  final List<StatItem> groups;
  final List<StatItem> ingredients;
  final List<StatItem> calm;

  /// The active test, or the latest completed one ending within 14 days.
  final ToleranceTestView? test;

  /// The server sent a [test] this build cannot read (so [test] is null): it
  /// may be active, so no test is offered.
  final bool hasUnreadableTest;

  /// Completed tests of the last 180 days, newest first.
  final List<TestedItem> tested;

  /// The subject core proposes to test; null while restrictive.
  final TestSubject? proposal;

  /// The restrictive-eating guard (spec §5.3): no „Testen" anywhere. A
  /// response without it reads as restrictive (safety).
  final bool restrictive;

  /// The latest completed test of [kind]/[key] that ended fewer than 60
  /// days before [today] (core's bound: ages 0–59) (the device's today when omitted); null otherwise.
  TestedItem? testedFor(String kind, String key, {DateTime? today}) {
    final day = startOfDay(today ?? DateTime.now());
    TestedItem? latest;
    for (final t in tested) {
      if (t.subject.kind != kind || t.subject.key != key) continue;
      final age = daysBetween(t.endedOn, day);
      if (age < 0 || age >= 60) continue;
      if (latest == null || t.endedOn.isAfter(latest.endedOn)) latest = t;
    }
    return latest;
  }

  /// Unknown keys are ignored; an item that is malformed or has an unknown
  /// level is dropped, as are a tested item or proposal this build cannot read. A test it cannot
  /// read is dropped too, but marked ([hasUnreadableTest]).
  factory PatternStats.fromJson(Map<String, dynamic> j) {
    final rawTest = j['test'];
    final test = _tryParse(rawTest, ToleranceTestView.fromJson);
    return PatternStats(
      windowDays: j['window_days'] as int,
      ratedDays: j['rated_days'] as int,
      hardDays: j['hard_days'] as int,
      ready: j['ready'] as bool,
      groups: _list(j['groups'], StatItem.fromJson),
      ingredients: _list(j['ingredients'], StatItem.fromJson),
      calm: _list(j['calm'], StatItem.fromJson),
      test: test,
      hasUnreadableTest: rawTest != null && test == null,
      tested: _list(j['tested'], TestedItem.fromJson),
      proposal: _tryParse(j['proposal'], TestSubject.fromJson),
      restrictive: j['restrictive'] as bool? ?? true,
    );
  }

  static T? _tryParse<T>(Object? raw, T Function(Map<String, dynamic>) parse) {
    if (raw is! Map<String, dynamic>) return null;
    try {
      return parse(raw);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// The items of [raw] this build can read; a malformed one (unknown wire
  /// value, missing field, wrong type) is dropped, never failing the whole
  /// fetch.
  static List<T> _list<T>(
    Object? raw,
    T Function(Map<String, dynamic>) parse,
  ) => [for (final row in raw is List ? raw : const []) ?_tryParse(row, parse)];

  /// Ingredients with `nestedIn == group.key`, in server order.
  List<StatItem> membersOf(StatItem group) => [
    for (final i in ingredients)
      if (i.nestedIn == group.key) i,
  ];

  /// Ingredients with no group they are nested in.
  List<StatItem> get loose => [
    for (final i in ingredients)
      if (i.nestedIn == null) i,
  ];
}
