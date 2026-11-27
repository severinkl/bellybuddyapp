import '../../models/alternative_choice.dart';
import '../../models/ingredient_suggestion_group.dart';
import '../../models/ranked_replacement.dart';
import '../../models/replacement_ingredient.dart';

export '../../models/ranked_replacement.dart';

/// A meal as the ranking reads it: `tracked_at` (wall clock, never
/// converted) and its ingredient names.
typedef MealIngredients = ({DateTime trackedAt, List<String> ingredients});

/// How far back the meals for „eaten afterwards" are read.
const rankingMealDays = 180;

/// [name] lower case, trimmed, cut at the first „ (": „Tofu (fest, natur)"
/// and „Tofu" are siblings.
String baseName(String name) {
  final lower = name.trim().toLowerCase();
  final cut = lower.indexOf(' (');
  return (cut < 0 ? lower : lower.substring(0, cut)).trim();
}

/// The user's verdicts from their `alternative_choices` rows.
class AlternativeVerdicts {
  AlternativeVerdicts(List<AlternativeChoice> choices)
    : _byIngredient = {
        for (final c in choices)
          c.ingredientId: <String, AlternativeChoiceKind>{},
      },
      skippedBaseNames = {
        for (final c in choices)
          if (c.kind == AlternativeChoiceKind.skip) baseName(c.replacementName),
      } {
    for (final c in choices) {
      _byIngredient[c.ingredientId]![c.replacementId] = c.kind;
    }
  }

  final Map<String, Map<String, AlternativeChoiceKind>> _byIngredient;

  /// The base names of the replacements skipped on any pairing.
  final Set<String> skippedBaseNames;

  /// The verdicts on the replacements of [ingredientId], by replacement id.
  Map<String, AlternativeChoiceKind> forIngredient(String ingredientId) =>
      _byIngredient[ingredientId] ?? const {};
}

/// How many of [meals] list [name] (by base name) on a later local day
/// than [since]. [since] is a real instant (`created_at`), so its local
/// date is taken; `tracked_at` is wall clock and taken as it is. A meal on
/// the suggestion's own day does not count: it is usually the one that
/// caused it.
int _eatenAfter(String name, List<MealIngredients> meals, DateTime? since) {
  if (since == null) return 0;
  final local = since.toLocal();
  final sinceDay = DateTime(local.year, local.month, local.day);
  final base = baseName(name);
  var count = 0;
  for (final meal in meals) {
    final t = meal.trackedAt;
    if (!DateTime(t.year, t.month, t.day).isAfter(sinceDay)) continue;
    if (meal.ingredients.any((i) => baseName(i) == base)) count++;
  }
  return count;
}

int _tier(
  ReplacementIngredient r,
  AlternativeChoiceKind? verdict,
  int eatenAfter,
  Set<String> skippedBaseNames,
) => switch (verdict) {
  AlternativeChoiceKind.fits => 0,
  AlternativeChoiceKind.skip => 4,
  AlternativeChoiceKind.tryIt => 1,
  null when eatenAfter > 0 => 1,
  null when skippedBaseNames.contains(baseName(r.name)) => 3,
  null => RankedReplacement.neutralTier,
};

/// [ranked] with [verdicts] (by replacement id) and the siblings of
/// [skippedBaseNames], ordered by tier, then more meals eaten afterwards
/// first, then the original order.
List<RankedReplacement> _order(
  Iterable<RankedReplacement> ranked,
  Map<String, AlternativeChoiceKind> verdicts,
  Set<String> skippedBaseNames,
) {
  final skipped = {
    ...skippedBaseNames,
    for (final r in ranked)
      if (verdicts[r.id] == AlternativeChoiceKind.skip) baseName(r.name),
  };
  return [
    for (final r in ranked)
      RankedReplacement(
        replacement: r.replacement,
        verdict: verdicts[r.id],
        eatenAfter: r.eatenAfter,
        tier: _tier(r.replacement, verdicts[r.id], r.eatenAfter, skipped),
        index: r.index,
      ),
  ]..sort((a, b) {
    if (a.tier != b.tier) return a.tier.compareTo(b.tier);
    if (a.eatenAfter != b.eatenAfter) {
      return b.eatenAfter.compareTo(a.eatenAfter);
    }
    return a.index.compareTo(b.index);
  });
}

/// [replacements] (in the server's order) ranked by spec §6.3: tier 0
/// „Passt für mich"; 1 „Probiere ich" or eaten afterwards; 2 neutral; 3 a
/// sibling (same [baseName]) of one skipped on any pairing
/// ([skippedBaseNames], plus those [verdicts] skip), not itself skipped; 4
/// „Passt nicht für mich". Within a tier: more meals eaten after [since]
/// first, then the original order.
///
/// [verdicts] are the choices for the group's ingredient, by replacement
/// id; [since] is the group's first suggestion's `created_at`.
List<RankedReplacement> rankReplacements(
  List<ReplacementIngredient> replacements, {
  required Map<String, AlternativeChoiceKind> verdicts,
  Set<String> skippedBaseNames = const {},
  required List<MealIngredients> meals,
  required DateTime? since,
}) => _order(
  [
    for (final (i, r) in replacements.indexed)
      RankedReplacement(
        replacement: r,
        eatenAfter: _eatenAfter(r.name, meals, since),
        index: i,
      ),
  ],
  verdicts,
  skippedBaseNames,
);

/// [groups] ranked again with [choices] (the meals eaten afterwards stay as
/// they were counted).
List<IngredientSuggestionGroup> rerankGroups(
  List<IngredientSuggestionGroup> groups,
  List<AlternativeChoice> choices,
) {
  final verdicts = AlternativeVerdicts(choices);
  return [
    for (final g in groups)
      g.replacements.isEmpty
          ? g
          : g.copyWith(
              replacements: _order(
                g.replacements,
                verdicts.forIngredient(g.ingredientId),
                verdicts.skippedBaseNames,
              ),
            ),
  ];
}
