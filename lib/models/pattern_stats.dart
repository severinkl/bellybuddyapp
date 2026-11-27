/// How noticeable a food or FODMAP group is in the pattern comparison
/// (wire values of core's `pattern-stats`). Always relative, never a verdict.
enum StatLevel {
  strong,
  noticed,
  unsure,
  calm;

  /// The level for a wire value; null for one this build does not know.
  static StatLevel? fromWire(Object? value) {
    for (final level in values) {
      if (level.name == value) return level;
    }
    return null;
  }
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
    final level = StatLevel.fromWire(j['level']);
    if (level == null) throw FormatException('unknown level: ${j['level']}');
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
  });

  final int windowDays;
  final int ratedDays;
  final int hardDays;
  final bool ready;
  final List<StatItem> groups;
  final List<StatItem> ingredients;
  final List<StatItem> calm;

  /// Unknown keys are ignored; an item with an unknown level is dropped.
  factory PatternStats.fromJson(Map<String, dynamic> j) => PatternStats(
    windowDays: j['window_days'] as int,
    ratedDays: j['rated_days'] as int,
    hardDays: j['hard_days'] as int,
    ready: j['ready'] as bool,
    groups: _items(j['groups']),
    ingredients: _items(j['ingredients']),
    calm: _items(j['calm']),
  );

  static List<StatItem> _items(Object? raw) {
    final items = <StatItem>[];
    for (final row in (raw as List?) ?? const []) {
      if (row is Map<String, dynamic> &&
          StatLevel.fromWire(row['level']) != null) {
        items.add(StatItem.fromJson(row));
      }
    }
    return items;
  }

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
