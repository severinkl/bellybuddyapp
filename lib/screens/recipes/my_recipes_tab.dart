import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/user_recipes_provider.dart';
import '../../router/route_names.dart';
import '../../widgets/common/mascot_image.dart';
import 'widgets/recipe_list_tile.dart';

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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(
        child: Text(
          'Konnte Rezepte nicht laden',
          style: TextStyle(
            fontSize: AppTheme.fontSizeBody,
            color: AppTheme.mutedForeground,
          ),
        ),
      ),
      data: (recipes) {
        if (recipes.isEmpty) return const _EmptyState();
        return ListView.separated(
          padding: AppConstants.paddingMd,
          itemCount: recipes.length,
          separatorBuilder: (context, index) => AppConstants.gap8,
          itemBuilder: (context, i) {
            final recipe = recipes[i];
            return RecipeListTile(
              recipe: recipe,
              onTap: () => context.push('${RoutePaths.recipes}/${recipe.id}'),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
              onPressed: () {
                // Opens the add-new chooser. Wired in Task 13.
                // Temporarily a no-op; Phase 5 will wire it.
              },
              child: const Text('Erstes Rezept erstellen'),
            ),
          ],
        ),
      ),
    );
  }
}
