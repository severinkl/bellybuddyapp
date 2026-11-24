import 'package:flutter/foundation.dart';

import '../../models/intolerance_rules.dart';
import '../../models/recipe.dart';
import 'recipe_copy.dart';

/// How one ingredient line fits the user.
enum LineMark {
  /// Nothing of the user's intolerances (✓), all of which the catalog can
  /// judge.
  fits,

  /// Nothing of the intolerances the catalog can judge, while the user has
  /// one it can't (Histamin): no ✓, which would read like a verdict on it.
  neutral,

  /// Hits one of the user's intolerances (⚠ „— für dich kritisch").
  kritisch,

  /// Not in the catalog while an intolerance needs its FODMAP flags
  /// („nicht im Katalog").
  unknown,
}

/// One ingredient line and how it fits the user.
class LineFit {
  const LineFit(this.line, this.mark, {this.because = const []});

  final RecipeIngredient line;
  final LineMark mark;

  /// The intolerances a kritisch line hits, in profile order („wegen …").
  final List<String> because;
}

/// The badge of a recipe: „Passt zu dir", „N Zutaten sind für dich
/// kritisch" or „Histamin bitte selbst prüfen".
sealed class FitBadge {
  const FitBadge();

  String get label;
}

final class FitsBadge extends FitBadge {
  const FitsBadge();

  @override
  String get label => RecipeCopy.fits;

  @override
  bool operator ==(Object other) => other is FitsBadge;

  @override
  int get hashCode => (FitsBadge).hashCode;

  @override
  String toString() => 'FitsBadge()';
}

final class KritischBadge extends FitBadge {
  const KritischBadge(this.count);

  /// The kritisch lines, at least 1.
  final int count;

  @override
  String get label => RecipeCopy.kritisch(count);

  @override
  bool operator ==(Object other) =>
      other is KritischBadge && other.count == count;

  @override
  int get hashCode => count.hashCode;

  @override
  String toString() => 'KritischBadge($count)';
}

final class SelfCheckBadge extends FitBadge {
  const SelfCheckBadge(this.intolerances);

  /// The user's intolerances the catalog can't judge.
  final List<String> intolerances;

  @override
  String get label => RecipeCopy.selfCheck(intolerances);

  @override
  bool operator ==(Object other) =>
      other is SelfCheckBadge && listEquals(other.intolerances, intolerances);

  @override
  int get hashCode => Object.hashAll(intolerances);

  @override
  String toString() => 'SelfCheckBadge($intolerances)';
}

/// How a collection recipe fits the user ([fitOf]).
class RecipeFit {
  const RecipeFit({
    required this.recipe,
    required this.checked,
    this.lines = const [],
    this.selfCheck = const [],
    this.judged = false,
  });

  final Recipe recipe;

  /// Whether the intolerance table and the user's intolerances are known.
  /// Otherwise nothing is judged: no lines, no badge.
  final bool checked;

  /// One per [Recipe.ingredients] when [checked]; empty otherwise.
  final List<LineFit> lines;

  /// The user's intolerances the catalog can't judge (Histamin), in profile
  /// order.
  final List<String> selfCheck;

  /// Whether every line could be judged: [checked], no
  /// [LineMark.unknown] line, and not an older recipe while the user has a
  /// judgeable intolerance.
  final bool judged;

  List<LineFit> get kritisch => [
    for (final l in lines)
      if (l.mark == LineMark.kritisch) l,
  ];

  int get kritischCount => kritisch.length;

  /// Null while unchecked, and while an unjudged recipe has no kritisch
  /// line: nothing that reads like a verdict.
  FitBadge? get badge {
    if (!checked) return null;
    final count = kritischCount;
    if (count > 0) return KritischBadge(count);
    if (!judged) return null;
    if (selfCheck.isNotEmpty) return SelfCheckBadge(selfCheck);
    return const FitsBadge();
  }

  /// Whether the recipe passes „Passt zu mir" (which ignores [selfCheck]).
  bool get passtZuMir => checked && judged && kritischCount == 0;
}

/// How [recipe] fits a user with [intolerances] (profile values) by
/// [rules]; unchecked while either is unknown.
RecipeFit fitOf(
  Recipe recipe, {
  required IntoleranceRules? rules,
  required List<String>? intolerances,
}) => UserIntolerances(rules, intolerances).fit(recipe);

/// The user's intolerances resolved against the table, once for many
/// recipes ([fit] is [fitOf]).
///
/// An ingredient is kritisch, as in core's `critical_hits`, when it carries
/// an allergen of one of the judgeable rules, or when its catalog row has a
/// FODMAP flag of one of them and the stated amount is not low-FODMAP. An
/// unmapped line has no flags, so only its allergens count. The other lines
/// are [LineMark.fits], or [LineMark.neutral] while an intolerance can't be
/// judged.
class UserIntolerances {
  factory UserIntolerances(
    IntoleranceRules? rules,
    List<String>? intolerances,
  ) {
    if (rules == null || intolerances == null) {
      return const UserIntolerances._(checked: false);
    }
    final named = [
      for (final name in intolerances.toSet())
        if (rules[name] case final rule?) (name: name, rule: rule),
    ];
    return UserIntolerances._(
      checked: true,
      judgeable: [
        for (final r in named)
          if (r.rule.judgeable) r,
      ],
      selfCheck: List.unmodifiable([
        for (final r in named)
          if (!r.rule.judgeable) r.name,
      ]),
    );
  }

  const UserIntolerances._({
    required this.checked,
    List<({String name, IntoleranceRule rule})> judgeable = const [],
    this.selfCheck = const [],
  }) : _judgeable = judgeable;

  /// Whether the table and the intolerances are known.
  final bool checked;

  /// The intolerances whose rule is not judgeable, in profile order.
  final List<String> selfCheck;

  /// The rules that decide the lines, in profile order; intolerances
  /// missing from the table hit nothing.
  final List<({String name, IntoleranceRule rule})> _judgeable;

  RecipeFit fit(Recipe recipe) {
    if (!checked) return RecipeFit(recipe: recipe, checked: false);
    final lines = [for (final line in recipe.ingredients) _lineFit(line)];
    final judged =
        !lines.any((l) => l.mark == LineMark.unknown) &&
        !(recipe.isLegacy && _judgeable.isNotEmpty);
    return RecipeFit(
      recipe: recipe,
      checked: true,
      lines: List.unmodifiable(lines),
      selfCheck: selfCheck,
      judged: judged,
    );
  }

  LineFit _lineFit(RecipeIngredient line) {
    final because = [
      for (final r in _judgeable)
        if (_hits(r.rule, line)) r.name,
    ];
    if (because.isNotEmpty) {
      return LineFit(line, LineMark.kritisch, because: because);
    }
    if (!line.mapped && _judgeable.any((r) => r.rule.fodmaps.isNotEmpty)) {
      return LineFit(line, LineMark.unknown);
    }
    return LineFit(line, selfCheck.isEmpty ? LineMark.fits : LineMark.neutral);
  }

  static bool _hits(IntoleranceRule rule, RecipeIngredient line) {
    if (rule.allergens.any(line.allergens.contains)) return true;
    final fodmaps = line.fodmaps;
    return !line.lowAtAmount &&
        fodmaps != null &&
        rule.fodmaps.any(fodmaps.has);
  }
}
