import 'dart:convert';

import 'fodmap_flags.dart';

/// What one intolerance (a `profiles.intolerances` value) reacts to.
class IntoleranceRule {
  const IntoleranceRule({
    this.fodmaps = const {},
    this.allergens = const {},
    this.judgeable = true,
  });

  /// FODMAP keys of the catalog row ([FodmapFlags.keys]).
  final Set<String> fodmaps;

  /// `recipe_ingredients.allergens` values.
  final Set<String> allergens;

  /// False when the catalog can't judge it (Histamin).
  final bool judgeable;
}

/// The intolerance table core publishes as `app_config.intolerance_rules`.
///
/// A profile value missing from the table hits nothing.
class IntoleranceRules {
  const IntoleranceRules(this.byName);

  final Map<String, IntoleranceRule> byName;

  /// Reads `{name: {"fodmaps": [...], "allergens": [...], "judgeable": bool}}`.
  /// Null unless [value] is a JSON object; entries that aren't objects are
  /// skipped, and unknown FODMAP keys dropped.
  static IntoleranceRules? parse(String value) {
    final Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    return IntoleranceRules({
      for (final MapEntry(:key, value: entry) in decoded.entries)
        if (entry is Map<String, dynamic>)
          key: IntoleranceRule(
            fodmaps: _strings(
              entry['fodmaps'],
            ).where(FodmapFlags.keys.contains).toSet(),
            allergens: _strings(entry['allergens']).toSet(),
            judgeable: entry['judgeable'] != false,
          ),
    });
  }

  IntoleranceRule? operator [](String intolerance) => byName[intolerance];
}

Iterable<String> _strings(Object? value) =>
    value is List ? value.whereType<String>() : const [];
