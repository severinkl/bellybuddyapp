import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/my_recipe_item.dart';
import '../../providers/recipe_collection_provider.dart';
import '../../providers/recipe_search_provider.dart';
import '../../providers/user_recipes_provider.dart';
import '../../router/navigation_extensions.dart';
import '../../router/route_names.dart';
import '../../widgets/common/bb_async_state.dart';
import '../../widgets/common/mascot_image.dart';
import 'widgets/add_recipe_chooser_sheet.dart';
import 'widgets/recipe_card.dart';
import 'widgets/recipes_search_field.dart';

class MyRecipesTab extends ConsumerStatefulWidget {
  const MyRecipesTab({super.key});

  @override
  ConsumerState<MyRecipesTab> createState() => _MyRecipesTabState();
}

class _MyRecipesTabState extends ConsumerState<MyRecipesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(userRecipesProvider.notifier).fetch();
    });
  }

  static const _host = RecipeSearchHost.myRecipes;

  @override
  Widget build(BuildContext context) {
    // The search belongs to this screen (auto-disposed with it): Entdecken's
    // Meine Rezepte never shows its matches, nor does the meal tracker's
    // picker share its query.
    final async = ref.watch(recipeSearchProvider(_host));
    return async.when(
      loading: () => const BbLoadingState(),
      error: (e, _) => BbErrorState(
        message: 'Konnte Rezepte nicht laden',
        onRetry: () => ref.read(recipeSearchProvider(_host).notifier).retry(),
      ),
      data: (found) {
        final query = ref
            .read(recipeSearchProvider(_host).notifier)
            .activeQuery
            ?.toLowerCase();
        final hasActiveQuery = query != null;
        // The search finds own recipes only; the saved ones are matched by
        // title here.
        final recipes = mergeMyRecipes(found, [
          for (final saved in ref.watch(savedRecipesProvider))
            if (query == null ||
                saved.recipe.title.toLowerCase().contains(query))
              saved,
        ]);
        if (recipes.isEmpty && !hasActiveQuery) {
          // Saved recipes may still be on their way.
          final loading =
              ref.watch(recipeCollectionProvider).isLoading ||
              ref.watch(recipeFavoritesProvider).isLoading;
          return loading ? const BbLoadingState() : const _EmptyState();
        }
        return Column(
          children: [
            const Padding(
              padding: AppConstants.paddingMd,
              child: RecipesSearchField(host: _host),
            ),
            Expanded(
              child: recipes.isEmpty
                  ? const _EmptySearchResults()
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppConstants.spacingMd,
                        0,
                        AppConstants.spacingMd,
                        AppConstants.spacingMd,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: AppConstants.spacingSm,
                            mainAxisSpacing: AppConstants.spacingSm,
                            childAspectRatio: 0.78,
                          ),
                      itemCount: recipes.length,
                      itemBuilder: (context, i) => MyRecipeCard(
                        item: recipes[i],
                        onOpenOwn: (recipe) =>
                            context.push(RoutePaths.recipeDetailFor(recipe.id)),
                        onOpenSaved: (id) => unawaited(context.openRecipe(id)),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptySearchResults extends StatelessWidget {
  const _EmptySearchResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppConstants.spacingXl),
        child: Text(
          'Keine Treffer',
          style: TextStyle(
            fontSize: AppTheme.fontSizeBody,
            color: AppTheme.mutedForeground,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MascotImage(
              assetPath: AppConstants.mascotWink,
              width: 128,
              height: 128,
            ),
            AppConstants.gap24,
            const Text(
              'Noch keine Rezepte',
              style: TextStyle(
                fontSize: AppTheme.fontSizeTitle,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
              ),
            ),
            AppConstants.gap8,
            const Text(
              'Speichere wiederkehrende Mahlzeiten als Rezepte, um sie später schneller wieder einzutragen.',
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                color: AppTheme.mutedForeground,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            AppConstants.gap24,
            FilledButton(
              onPressed: () => showAddRecipeChooserSheet(context),
              child: const Text('Erstes Rezept erstellen'),
            ),
          ],
        ),
      ),
    );
  }
}
