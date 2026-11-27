import 'alternative_choice.dart';
import 'replacement_ingredient.dart';

/// A replacement of a suggestion group with what ranks it (spec §6.3):
/// the user's [verdict] on it for the group's ingredient, the meals with it
/// eaten after the group's first suggestion, and its [tier].
class RankedReplacement {
  const RankedReplacement({
    required this.replacement,
    this.verdict,
    this.eatenAfter = 0,
    this.tier = neutralTier,
    this.index = 0,
  });

  /// [replacements] in their order, without verdicts or meals.
  static List<RankedReplacement> inOrder(
    List<ReplacementIngredient> replacements,
  ) => [
    for (final (i, r) in replacements.indexed)
      RankedReplacement(replacement: r, index: i),
  ];

  /// The tier of a replacement without verdict, not eaten afterwards and no
  /// sibling of a skipped one.
  static const neutralTier = 2;

  final ReplacementIngredient replacement;

  /// The choice for (the group's ingredient, this replacement); null
  /// without one.
  final AlternativeChoiceKind? verdict;

  /// How many meals on a later local day than the group's first suggestion
  /// list it (by base name).
  final int eatenAfter;

  /// 0 fits, 1 try or eaten afterwards, 2 neutral, 3 sibling of a skipped
  /// one, 4 skipped.
  final int tier;

  /// Its position in the server's order, for ranking again.
  final int index;

  /// „Passt nicht für mich": left out of summaries, last in the detail.
  bool get skipped => verdict == AlternativeChoiceKind.skip;

  String get id => replacement.id;
  String get name => replacement.name;
  String? get imageUrl => replacement.imageUrl;
}
