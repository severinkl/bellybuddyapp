import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/recipe.dart';
import '../../../utils/url_utils.dart';

/// The illustrated stand-in of a recipe without a photo: a tint and an
/// outline icon per meal type.
class RecipePlaceholder extends StatelessWidget {
  const RecipePlaceholder({super.key, this.mealType});

  static const placeholderKey = Key('recipe_placeholder');

  final MealType? mealType;

  static Color tintOf(MealType? type) => switch (type) {
    MealType.breakfast => AppTheme.recipeTintBreakfast,
    MealType.lunch => AppTheme.recipeTintLunch,
    MealType.dinner => AppTheme.recipeTintDinner,
    MealType.snack => AppTheme.recipeTintSnack,
    null => AppTheme.recipeTintOther,
  };

  static IconData iconOf(MealType? type) => switch (type) {
    MealType.breakfast => Icons.free_breakfast_outlined,
    MealType.lunch => Icons.lunch_dining_outlined,
    MealType.dinner => Icons.dinner_dining_outlined,
    MealType.snack => Icons.cookie_outlined,
    null => Icons.restaurant_menu_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: placeholderKey,
      color: tintOf(mealType),
      child: Center(
        child: ExcludeSemantics(
          child: Icon(
            iconOf(mealType),
            size: AppConstants.iconSizeLg,
            color: AppTheme.foreground.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

/// A collection recipe's picture: its `image_url` (http or https) or the
/// placeholder of its first meal type. Fills the space it is given.
class RecipeImage extends StatelessWidget {
  const RecipeImage({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final type = recipe.mealTypes.firstOrNull;
    final url = recipe.imageUrl;
    if (url == null || !isHttpUrl(url)) {
      return RecipePlaceholder(mealType: type);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      // Still with reduced motion.
      placeholder: (context, _) => Shimmer.fromColors(
        enabled: !MediaQuery.disableAnimationsOf(context),
        baseColor: AppTheme.muted,
        highlightColor: AppTheme.background,
        child: const ColoredBox(color: AppTheme.muted),
      ),
      errorWidget: (_, _, _) => RecipePlaceholder(mealType: type),
    );
  }
}
