import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/user_recipe.dart';
import '../../providers/user_recipes_provider.dart';
import '../../router/navigation_extensions.dart';
import '../../router/route_names.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/signed_path_image.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

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
          onPressed: () => context.popOrGoDashboard(),
        ),
        title: Text(recipe.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(RoutePaths.recipeEditFor(recipe.id)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
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
                    if (recipe.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusLg,
                        ),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: SignedPathImage(pathOrUrl: recipe.imageUrl),
                        ),
                      ),
                      AppConstants.gap16,
                    ],
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
                label: 'Mahlzeit jetzt tracken',
                onPressed: () =>
                    context.push(RoutePaths.mealTracker, extra: recipe),
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
