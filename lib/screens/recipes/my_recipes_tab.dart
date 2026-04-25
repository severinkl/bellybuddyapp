import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/user_recipes_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userRecipesProvider);
    return async.when(
      loading: () => const BbLoadingState(),
      error: (e, _) => BbErrorState(
        message: 'Konnte Rezepte nicht laden',
        onRetry: () =>
            ref.read(userRecipesProvider.notifier).fetch(force: true),
      ),
      data: (recipes) {
        final hasActiveQuery = ref
            .watch(userRecipesProvider.notifier)
            .hasActiveQuery;
        if (recipes.isEmpty && !hasActiveQuery) return const _EmptyState();
        return Column(
          children: [
            const Padding(
              padding: AppConstants.paddingMd,
              child: RecipesSearchField(),
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
                      itemBuilder: (context, i) {
                        final recipe = recipes[i];
                        return RecipeCard(
                          recipe: recipe,
                          onTap: () => context.push(
                            RoutePaths.recipeDetailFor(recipe.id),
                          ),
                        );
                      },
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
              'Speichere Mahlzeiten als Rezepte, um sie schnell wieder einzutragen.',
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
