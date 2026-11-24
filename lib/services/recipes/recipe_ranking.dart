import 'package:flutter/foundation.dart';

import '../../config/constants.dart';
import '../../models/insights.dart';
import '../../models/recipe.dart';
import '../../utils/german_list.dart';
import 'recipe_fit.dart';

/// What the user's entries say about ingredients, for the ranking: keys
/// (trimmed, lower case) that rank a recipe up ([good]) or down
/// ([noticed]).
class RankingSignals {
  const RankingSignals({this.good = const {}, this.noticed = const {}});

  /// No insights: no signals. Locked: the calm-day ingredients rank up and
  /// nothing down. Unlocked: the shown good days' „oft dabei" rank up, the
  /// shown certain „Fällt mir auf" items down.
  factory RankingSignals.of(Insights? insights) {
    if (insights == null) return const RankingSignals();
    if (!insights.unlocked) {
      return RankingSignals(good: insights.calmDayIngredients);
    }
    return RankingSignals(
      good: {
        if (insights.goodDays.shown)
          for (final item in insights.goodDays.often) item.name.toLowerCase(),
      },
      noticed: {
        if (insights.showNoticed)
          for (final n in insights.noticed)
            if (!n.uncertain) n.name.toLowerCase(),
      },
    );
  }

  final Set<String> good, noticed;

  @override
  bool operator ==(Object other) =>
      other is RankingSignals &&
      setEquals(other.good, good) &&
      setEquals(other.noticed, noticed);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(good),
    Object.hashAllUnordered(noticed),
  );
}

/// Whether [recipe] fits the profile's [diet] (`alles`, `vegetarisch`,
/// `vegan`; anything else keeps every recipe).
bool fitsDiet(Recipe recipe, String? diet) => switch (diet) {
  'vegan' => recipe.dietTags.contains('vegan'),
  'vegetarisch' => recipe.dietTags.contains('vegetarisch'),
  _ => true,
};

/// 2 per distinct good key of [recipe]'s lines, minus 3 per distinct
/// noticed key; 0 for an older recipe.
int recipeScore(Recipe recipe, RankingSignals signals) {
  final keys = {for (final line in recipe.ingredients) ...line.matchKeys};
  return 2 * keys.intersection(signals.good).length -
      3 * keys.intersection(signals.noticed).length;
}

/// The collection for one user ([rankRecipes]).
class RankedRecipes {
  const RankedRecipes({
    required this.fits,
    required this.checked,
    this.selfCheck = const [],
    this.diet,
    this.hiddenByDiet = 0,
  });

  /// The recipes that fit the [diet], best first.
  final List<RecipeFit> fits;

  /// Whether the intolerance table and the user's intolerances are known
  /// ([RecipeFit.checked]); otherwise no fit has marks or a badge.
  final bool checked;

  /// The user's intolerances the catalog can't judge.
  final List<String> selfCheck;

  final String? diet;

  /// Recipes left out because they don't fit the [diet].
  final int hiddenByDiet;
}

/// [recipes] that fit [diet], each with its fit, best first: by
/// [recipeScore] (higher first), fewer kritisch ingredients, newer
/// `created_at` (without one last; imported recipes often share one), then
/// title in German order, case ignored (and id, so the order is the same on
/// every run).
RankedRecipes rankRecipes(
  List<Recipe> recipes, {
  required String? diet,
  required UserIntolerances user,
  required RankingSignals signals,
}) {
  final kept = recipes.where((r) => fitsDiet(r, diet)).toList();
  final scored = [
    for (final fit in kept.map(user.fit))
      (
        fit: fit,
        score: recipeScore(fit.recipe, signals),
        kritisch: fit.kritischCount,
      ),
  ]..sort(_compare);
  return RankedRecipes(
    fits: List.unmodifiable([for (final s in scored) s.fit]),
    checked: user.checked,
    selfCheck: user.selfCheck,
    diet: diet,
    hiddenByDiet: recipes.length - kept.length,
  );
}

typedef _Scored = ({RecipeFit fit, int score, int kritisch});

int _compare(_Scored a, _Scored b) {
  if (a.score != b.score) return b.score - a.score;
  if (a.kritisch != b.kritisch) return a.kritisch - b.kritisch;
  final ra = a.fit.recipe, rb = b.fit.recipe;
  final atA = ra.createdAt, atB = rb.createdAt;
  if (atA != atB) {
    if (atA == null) return 1;
    if (atB == null) return -1;
    final newer = atB.compareTo(atA);
    if (newer != 0) return newer;
  }
  final title = germanOrder(ra.title.toLowerCase(), rb.title.toLowerCase());
  return title != 0 ? title : ra.id.compareTo(rb.id);
}

/// „Für dich": the first [count] of [ranked] that pass „Passt zu mir" (all
/// pass while unchecked), topped up in rank order from the rest.
List<RecipeFit> pickForYou(
  List<RecipeFit> ranked, {
  int count = AppConstants.recipeForYouCount,
}) {
  bool passes(RecipeFit f) => !f.checked || f.passtZuMir;
  final picked = ranked.where(passes).take(count).toList();
  return [
    ...picked,
    ...ranked.where((f) => !passes(f)).take(count - picked.length),
  ];
}

/// [ranked] in order, kept when [mealType] (if set) is one of the recipe's,
/// it passes „Passt zu mir" (if [fitsOnly]), and [query] (trimmed, case
/// ignored; blank matches all) is in its title, a line's name or an older
/// recipe's line.
List<RecipeFit> filterRecipes(
  List<RecipeFit> ranked, {
  String query = '',
  MealType? mealType,
  bool fitsOnly = false,
}) {
  final q = query.trim().toLowerCase();
  bool matches(Recipe r) =>
      q.isEmpty ||
      r.title.toLowerCase().contains(q) ||
      r.ingredients.any((l) => l.name.toLowerCase().contains(q)) ||
      r.legacyIngredients.any((l) => l.toLowerCase().contains(q));
  return [
    for (final fit in ranked)
      if ((mealType == null || fit.recipe.mealTypes.contains(mealType)) &&
          (!fitsOnly || fit.passtZuMir) &&
          matches(fit.recipe))
        fit,
  ];
}
