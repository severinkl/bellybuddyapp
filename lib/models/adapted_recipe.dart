/// One ingredient of an `adapt-recipe` answer.
class AdaptedIngredient {
  const AdaptedIngredient({
    this.amount,
    required this.name,
    this.replaces,
    this.unknown = false,
  });

  /// Reads an entry of the answer's `ingredients`; a [FormatException]
  /// without a `name`.
  factory AdaptedIngredient.fromJson(Map<String, dynamic> json) =>
      AdaptedIngredient(
        amount: _blankToNull(json['amount']),
        name: _string(json, 'name').trim(),
        replaces: _blankToNull(json['replaces']),
        unknown: json['status'] == 'unbekannt',
      );

  /// E.g. „2 EL"; null when blank.
  final String? amount;
  final String name;

  /// The original ingredient this one swaps out; null when unchanged or
  /// added.
  final String? replaces;

  /// Not in the FODMAP catalog (`status: unbekannt`).
  final bool unknown;
}

/// One step of an `adapt-recipe` answer; [changed] when it differs from the
/// original because of a swap.
class AdaptedStep {
  const AdaptedStep(this.text, {this.changed = false});

  factory AdaptedStep._fromJson(Map<String, dynamic> json) => AdaptedStep(
    _string(json, 'text').trim(),
    changed: json['changed'] == true,
  );

  final String text;
  final bool changed;
}

/// A collection recipe as `adapt-recipe` rebuilt it for the user.
class AdaptedRecipe {
  const AdaptedRecipe({
    required this.recipeId,
    required this.title,
    required this.ingredients,
    this.removed = const [],
    required this.steps,
    this.note = '',
  });

  /// Reads the 200 answer, trimmed, with blank ingredient names, removed
  /// names and steps dropped: what the app shows and saves is clean from
  /// here on. A [FormatException] without `recipe_id`, a title or
  /// ingredients, or with an entry that isn't one.
  factory AdaptedRecipe.fromJson(Map<String, dynamic> json) {
    final title = _string(json, 'title').trim();
    if (title.isEmpty) throw const FormatException('adapt: blank title');
    final ingredients = [
      for (final item in _list(json, 'ingredients'))
        if (AdaptedIngredient.fromJson(_map(item, 'ingredients'))
            case final ingredient when ingredient.name.isNotEmpty)
          ingredient,
    ];
    if (ingredients.isEmpty) {
      throw const FormatException('adapt: no ingredients');
    }
    return AdaptedRecipe(
      recipeId: _string(json, 'recipe_id'),
      title: title,
      ingredients: ingredients,
      removed: [
        for (final name in _list(json, 'removed', optional: true))
          ?_blankToNull(name),
      ],
      steps: [
        for (final item in _list(json, 'steps', optional: true))
          if (AdaptedStep._fromJson(_map(item, 'steps')) case final step
              when step.text.isNotEmpty)
            step,
      ],
      note: switch (json['note']) {
        final String note => note.trim(),
        _ => '',
      },
    );
  }

  /// The original recipe's id (`recipes.id`).
  final String recipeId;
  final String title;

  /// The Buddy's words about the swaps; may be blank.
  final String note;
  final List<AdaptedIngredient> ingredients;

  /// Original ingredients left out without a replacement.
  final List<String> removed;
  final List<AdaptedStep> steps;

  /// The ingredients not in the FODMAP catalog, in order.
  List<String> get unknownNames => [
    for (final ingredient in ingredients)
      if (ingredient.unknown) ingredient.name,
  ];
}

/// Why an adaptation did not come back.
enum AdaptFailure {
  /// Nothing is kritisch and the recipe fits the diet (409
  /// `nothing_to_adapt`).
  nothingToAdapt,

  /// As [nothingToAdapt], but resting on unknowns (409 `cannot_judge`).
  cannotJudge,

  /// Throttled or the AI service is busy (429).
  later,

  /// Anything else.
  failed;

  /// Whether trying again may help (else nothing would change).
  bool get retryable => switch (this) {
    later || failed => true,
    nothingToAdapt || cannotJudge => false,
  };
}

/// Thrown by `RecipeService.adapt`; the app shows its own copy per
/// [failure], never the server's message.
class AdaptRecipeException implements Exception {
  const AdaptRecipeException(this.failure);

  final AdaptFailure failure;

  @override
  String toString() => 'AdaptRecipeException(${failure.name})';
}

String _string(Map<String, dynamic> json, String key) => switch (json[key]) {
  final String value => value,
  _ => throw FormatException('adapt: "$key" is not a string'),
};

List<Object?> _list(
  Map<String, dynamic> json,
  String key, {
  bool optional = false,
}) => switch (json[key]) {
  final List<Object?> value => value,
  null when optional => const [],
  _ => throw FormatException('adapt: "$key" is not a list'),
};

Map<String, dynamic> _map(Object? item, String key) => switch (item) {
  final Map<String, dynamic> value => value,
  _ => throw FormatException('adapt: an entry of "$key" is not an object'),
};

String? _blankToNull(Object? value) {
  final trimmed = value is String ? value.trim() : null;
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
