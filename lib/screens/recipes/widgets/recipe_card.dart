import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../models/my_recipe_item.dart';
import '../../../models/user_recipe.dart';
import '../../../utils/title_color.dart';
import '../../../widgets/common/signed_path_image.dart';
import 'recipe_collection_card.dart';

/// An own recipe as a card: its photo (or a monogram), „Angepasst" when
/// the Buddy adapted it, the title and its first ingredients.
class RecipeCard extends StatelessWidget {
  const RecipeCard({super.key, required this.recipe, required this.onTap});

  final UserRecipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => RecipeCardShell(
    image: _Image(recipe: recipe),
    tag: recipe.isAdapted ? RecipeCardTag.adapted : null,
    title: recipe.title.isEmpty ? 'Ohne Namen' : recipe.title,
    subtitle: recipe.ingredients.take(3).join(' · '),
    onTap: onTap,
  );
}

/// An entry of „Meine Rezepte": an own recipe's card, or a saved one's with
/// the heart.
class MyRecipeCard extends StatelessWidget {
  const MyRecipeCard({
    super.key,
    required this.item,
    required this.onOpenOwn,
    required this.onOpenSaved,
  });

  final MyRecipeItem item;
  final ValueChanged<UserRecipe> onOpenOwn;

  /// A saved collection recipe, by id.
  final ValueChanged<String> onOpenSaved;

  @override
  Widget build(BuildContext context) => switch (item) {
    OwnRecipe(:final recipe) => RecipeCard(
      recipe: recipe,
      onTap: () => onOpenOwn(recipe),
    ),
    SavedRecipe(:final recipe) => RecipeCollectionCard(
      recipe: recipe,
      tag: RecipeCardTag.saved,
      onTap: () => onOpenSaved(recipe.id),
    ),
  };
}

class _Image extends StatelessWidget {
  const _Image({required this.recipe});
  final UserRecipe recipe;

  @override
  Widget build(BuildContext context) {
    if (recipe.imageUrl == null || recipe.imageUrl!.isEmpty) {
      return _PastelMonogram(title: recipe.title);
    }
    return SignedPathImage(
      pathOrUrl: recipe.imageUrl,
      placeholder: _PastelMonogram(title: recipe.title),
      errorWidget: _PastelMonogram(title: recipe.title),
    );
  }
}

class _PastelMonogram extends StatelessWidget {
  const _PastelMonogram({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final letter = title.isEmpty ? '?' : title.characters.first.toUpperCase();
    return Container(
      color: pastelForTitle(title),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: AppTheme.fontSizeTitleLG,
          fontWeight: FontWeight.w300,
          color: AppTheme.foreground.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}
