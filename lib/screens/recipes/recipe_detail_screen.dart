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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusLg,
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _RecipeImage(recipe: recipe),
                      ),
                    ),
                    AppConstants.gap16,
                    Text(
                      recipe.title,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeDisplay,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.foreground,
                      ),
                    ),
                    AppConstants.gap16,
                    if (recipe.ingredients.isNotEmpty) ...[
                      const Text(
                        'Zutaten',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeSubtitle,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.foreground,
                        ),
                      ),
                      AppConstants.gap8,
                      Wrap(
                        spacing: AppConstants.spacingSm,
                        runSpacing: AppConstants.spacingSm,
                        children: [
                          for (final ingredient in recipe.ingredients)
                            Chip(label: Text(ingredient)),
                        ],
                      ),
                    ],
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
