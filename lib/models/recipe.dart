import '../utils/ingredient_key.dart';
import '../utils/json_values.dart';
import '../utils/url_utils.dart';
import 'fodmap_flags.dart';

/// A meal type of the collection (`recipes.meal_types`), in display order.
enum MealType {
  breakfast('frühstück', 'Frühstück'),
  lunch('mittag', 'Mittag'),
  dinner('abend', 'Abend'),
  snack('snack', 'Snack');

  const MealType(this.key, this.label);

  /// The value stored in `recipes.meal_types`.
  final String key;
  final String label;

  static MealType? fromKey(String key) {
    for (final type in values) {
      if (type.key == key) return type;
    }
    return null;
  }
}

/// One line of a collection recipe (a `recipe_ingredients` row).
class RecipeIngredient {
  const RecipeIngredient({
    required this.position,
    this.amount,
    required this.name,
    this.catalogId,
    this.catalogName,
    this.fodmaps,
    this.allergens = const {},
    this.lowAtAmount = false,
  });

  /// Reads a `recipe_ingredients` row with its embedded `ingredient` catalog
  /// row (null when the line is not in the catalog).
  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    final catalog = json['ingredient'] as Map<String, dynamic>?;
    return RecipeIngredient(
      position: (json['position'] as num).toInt(),
      amount: trimmedOrNull(json['amount_text']),
      name: json['name'] as String,
      catalogId: catalog?['id'] as String?,
      catalogName: catalog?['name'] as String?,
      fodmaps: catalog == null ? null : FodmapFlags.fromDbRow(catalog),
      allergens: jsonStrings(json['allergens']).toSet(),
      lowAtAmount: json['low_at_amount'] as bool? ?? false,
    );
  }

  final int position;

  /// `amount_text`, e.g. „200 g"; null when blank.
  final String? amount;

  /// The German name shown to the user.
  final String name;

  /// The linked catalog row; both null when the line is unmapped
  /// („unbekannt").
  final String? catalogId, catalogName;

  /// The catalog row's FODMAP flags; null when unmapped.
  final FodmapFlags? fodmaps;

  /// Allergen tags (`gluten`, `weizen`, `milch`, `nuesse`, `eier`, `soja`).
  final Set<String> allergens;

  /// The stated amount per portion is low-FODMAP.
  final bool lowAtAmount;

  bool get mapped => catalogId != null;

  /// The line's name and catalog name as [ingredientKey]s (trimmed,
  /// lower-cased), for matching against diary ingredients.
  Set<String> get matchKeys => {
    for (final key in [name, ?catalogName]) ingredientKey(key),
  }..remove('');
}

/// A recipe of the curated collection (`recipes`).
class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    this.description,
    this.cookTime,
    this.servings,
    this.imageUrl,
    this.mealTypes = const [],
    this.dietTags = const {},
    this.sourceName,
    this.sourceUrl,
    this.instructions = const [],
    this.ingredients = const [],
    this.legacyIngredients = const [],
    this.createdAt,
  });

  /// Reads a row of `RecipeService.collectionSelect`.
  factory Recipe.fromJson(Map<String, dynamic> json) {
    final mealKeys = jsonStrings(
      json['meal_types'],
    ).map(MealType.fromKey).toSet();
    final lines = [
      for (final row in (json['recipe_ingredients'] as List?) ?? const [])
        RecipeIngredient.fromJson(row as Map<String, dynamic>),
    ]..sort((a, b) => a.position.compareTo(b.position));
    final createdAt = json['created_at'] as String?;
    return Recipe(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      cookTime: trimmedOrNull(json['cook_time']?.toString()),
      servings: (json['servings'] as num?)?.toInt(),
      imageUrl: json['image_url'] as String?,
      mealTypes: MealType.values.where(mealKeys.contains).toList(),
      dietTags: jsonStrings(json['diet_tags']).toSet(),
      sourceName: json['source_name'] as String?,
      sourceUrl: json['source_url'] as String?,
      instructions: jsonStrings(json['instructions']).toList(),
      ingredients: lines,
      legacyIngredients: jsonStrings(json['ingredients']).toList(),
      createdAt: createdAt == null ? null : DateTime.parse(createdAt),
    );
  }

  final String id, title;
  final String? description, cookTime, imageUrl, sourceName, sourceUrl;
  final int? servings;

  /// In enum order; unknown keys are dropped.
  final List<MealType> mealTypes;

  /// ⊆ `vegan`, `vegetarisch`; a vegan recipe carries both.
  final Set<String> dietTags;
  final List<String> instructions;

  /// Sorted by position; empty for an older recipe.
  final List<RecipeIngredient> ingredients;

  /// The `ingredients` text column, which older recipes use instead of lines.
  final List<String> legacyIngredients;
  final DateTime? createdAt;

  /// One of the recipes from before the collection, without lines.
  bool get isLegacy => ingredients.isEmpty;

  String? get servingsLabel => switch (servings) {
    null => null,
    1 => '1 Portion',
    final n => '$n Portionen',
  };

  /// The source's address, trimmed, when it is a web link (http, https);
  /// null otherwise.
  String? get sourceLink {
    final url = sourceUrl?.trim();
    return url != null && isHttpUrl(url) ? url : null;
  }

  /// The source's name, else its site ([sourceLink]'s host); null when
  /// neither is known.
  String? get sourceLabel {
    final name = sourceName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final host = Uri.tryParse(sourceLink ?? '')?.host ?? '';
    return host.isEmpty ? null : host;
  }

  /// „35 Min · 2 Portionen".
  String get detailMeta => [cookTime, servingsLabel].nonNulls.join(' · ');

  /// „35 Min · Mittag".
  String get listMeta =>
      [cookTime, mealTypes.firstOrNull?.label].nonNulls.join(' · ');
}

/// A recipe the user marked „Merken", with the time they did.
class FavoriteRecipe {
  const FavoriteRecipe(this.recipeId, this.at);

  final String recipeId;
  final DateTime at;
}
