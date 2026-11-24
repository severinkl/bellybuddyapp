import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/meal_prefill.dart';
import '../../models/user_recipe.dart';
import '../../providers/user_recipes_provider.dart';
import '../../router/navigation_extensions.dart';
import '../../router/route_names.dart';
import '../../widgets/common/bb_button.dart';
import '../../utils/title_color.dart';
import '../../widgets/common/signed_path_image.dart';
import '../../providers/recipe_collection_provider.dart';
import 'widgets/ingredient_line_view.dart';
import 'widgets/recipe_collection_card.dart';
import 'widgets/recipe_page_parts.dart';
import 'widgets/recipe_steps.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

  /// Stands in for the photo of a recipe without one.
  static const imagePlaceholderKey = Key('recipe_detail_image_placeholder');

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(userRecipesProvider.notifier).fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userRecipesProvider);

    // Show a spinner while the list is loading (deep-link cold-start) so
    // the screen doesn't briefly flash "Rezept nicht gefunden" before the
    // fetch resolves.
    if (!async.hasValue) {
      return Scaffold(
        backgroundColor: AppTheme.screenBackground,
        appBar: AppBar(
          backgroundColor: AppTheme.screenBackground,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Zurück',
            onPressed: () => context.popOrGoDashboard(),
          ),
          title: const Text('Rezept'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final recipe = async.value!
        .where((r) => r.id == widget.recipeId)
        .firstOrNull;

    if (recipe == null) {
      return Scaffold(
        backgroundColor: AppTheme.screenBackground,
        appBar: AppBar(
          backgroundColor: AppTheme.screenBackground,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Zurück',
            onPressed: () => context.popOrGoDashboard(),
          ),
          title: const Text('Rezept'),
        ),
        body: const Center(
          child: Text(
            'Rezept nicht gefunden',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.mutedForeground,
            ),
          ),
        ),
      );
    }

    final hasAmounts = [
      for (var i = 0; i < recipe.ingredients.length; i++) recipe.amountOf(i),
    ].any((a) => a != null);

    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Zurück',
          onPressed: () => context.popOrGoDashboard(),
        ),
        // The recipe's name is the page's heading below; said once.
        title: const Text('Rezept'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Bearbeiten',
            onPressed: () => context.push(RoutePaths.recipeEditFor(recipe.id)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Rezept löschen',
            onPressed: () => _confirmDelete(context, ref, recipe),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: AppConstants.paddingMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RecipePageHead(
                      image: _RecipeImage(recipe: recipe),
                      tag: recipe.isAdapted ? RecipeCardTag.adapted : null,
                      title: recipe.title,
                    ),
                    if (recipe.adaptedFromRecipeId case final originalId?)
                      _OriginalLink(recipeId: originalId),
                    AppConstants.gap16,
                    if (recipe.ingredients.isNotEmpty)
                      RecipeSectionCard(
                        title: 'Zutaten',
                        children: [
                          for (var i = 0; i < recipe.ingredients.length; i++)
                            IngredientLineView(
                              amount: recipe.amountOf(i),
                              name: recipe.ingredients[i],
                              amountColumn: hasAmounts,
                            ),
                        ],
                      ),
                    AppConstants.gap16,
                    RecipeSectionCard(
                      title: 'Zubereitung',
                      trailing: recipe.instructions.isEmpty
                          ? const Text(
                              'optional',
                              style: RecipeSectionCard.captionStyle,
                            )
                          : null,
                      children: [
                        if (recipe.instructions.isEmpty) ...[
                          const Text(
                            'Noch keine Schritte.',
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeBody,
                              color: AppTheme.mutedForeground,
                            ),
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              onPressed: () => context.push(
                                RoutePaths.recipeEditFor(recipe.id),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Schritte hinzufügen'),
                            ),
                          ),
                        ] else
                          RecipeSteps(steps: recipe.instructions),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: AppConstants.paddingMd,
              child: BbButton(
                label: 'Jetzt als Essen eintragen',
                onPressed: () => context.push(
                  RoutePaths.mealTracker,
                  extra: MealPrefill.ofUserRecipe(recipe),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    UserRecipe recipe,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rezept löschen?'),
        content: Text('${recipe.title} wird entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.destructive),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await ref.read(userRecipesProvider.notifier).delete(recipe.id);
    if (context.mounted) context.pop();
  }
}

/// The recipe's photo, or, without one (or while it can't load), a pastel
/// placeholder with a book glyph, like the recipe cards.
class _RecipeImage extends StatelessWidget {
  const _RecipeImage({required this.recipe});

  final UserRecipe recipe;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      key: RecipeDetailScreen.imagePlaceholderKey,
      color: pastelForTitle(recipe.title),
      alignment: Alignment.center,
      child: Icon(
        Icons.menu_book_outlined,
        size: AppConstants.iconSizeLg,
        color: AppTheme.foreground.withValues(alpha: 0.45),
      ),
    );
    final url = recipe.imageUrl;
    if (url == null || url.isEmpty) return placeholder;
    return SignedPathImage(
      pathOrUrl: url,
      placeholder: placeholder,
      errorWidget: placeholder,
    );
  }
}

/// „Original: <title> ›" for an adapted recipe whose original is still in
/// the collection; nothing otherwise.
class _OriginalLink extends ConsumerWidget {
  const _OriginalLink({required this.recipeId});

  final String recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final original = ref.watch(collectionRecipeProvider(recipeId)).value;
    if (original == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.spacingSm),
      child: RecipeLinkLine(
        lead: 'Original: ',
        name: original.title,
        onTap: () => unawaited(context.openRecipe(recipeId)),
      ),
    );
  }
}
