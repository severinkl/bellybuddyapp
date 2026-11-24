import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/recipe_collection_provider.dart';
import '../../../router/navigation_extensions.dart';
import '../../../widgets/common/bb_card.dart';
import '../../recipes/widgets/recipe_image.dart';

/// „Passendes Rezept: …" under a Tausch-Tipp, spaced from what is above
/// it; opens the collection recipe [recipeId]. Nothing unless the loaded
/// collection holds it: hidden since, or the collection loading or failed.
class TipRecipeLink extends ConsumerWidget {
  const TipRecipeLink({super.key, required this.recipeId, this.title});

  final String recipeId;

  /// The title saved with the tip; else the collection recipe's.
  final String? title;

  /// The link's row, while it shows.
  static Key keyFor(String recipeId) => ValueKey('tip_recipe_link_$recipeId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(collectionRecipeProvider(recipeId)).value;
    if (recipe == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.spacing10),
      // One button, read as its text: „Passendes Rezept: <title>".
      child: BbCard(
        key: keyFor(recipeId),
        onTap: () => context.openRecipe(recipeId),
        color: AppTheme.background,
        radius: AppConstants.radiusMd,
        padding: const EdgeInsets.all(AppConstants.spacingSm),
        child: Row(
          children: [
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                child: SizedBox.square(
                  dimension: AppConstants.tipRecipeThumbSize,
                  child: RecipeImage(recipe: recipe),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spacing10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Passendes Rezept: ',
                      style: TextStyle(color: AppTheme.mutedForeground),
                    ),
                    TextSpan(
                      text: title ?? recipe.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.foreground,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: AppTheme.fontSizeBody),
              ),
            ),
            const SizedBox(width: AppConstants.spacingXs),
            const Icon(
              Icons.chevron_right,
              size: AppConstants.iconSizeClose,
              color: AppTheme.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}
