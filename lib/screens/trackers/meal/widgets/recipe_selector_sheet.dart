import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../models/user_recipe.dart';
import '../../../../providers/user_recipes_provider.dart';
import '../../../../router/route_names.dart';
import '../../../../utils/title_color.dart';
import '../../../../widgets/common/signed_path_image.dart';
import '../../../recipes/widgets/recipes_search_field.dart';

/// Opens a modal bottom sheet that lets the user pick one of their saved
/// recipes. Resolves with the chosen [UserRecipe], or `null` if dismissed
/// (including when the user taps "Neues Rezept erstellen" to create a new
/// one instead).
Future<UserRecipe?> showRecipeSelectorSheet(BuildContext context) {
  return showModalBottomSheet<UserRecipe>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppConstants.radiusXl),
      ),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => SafeArea(
        top: false,
        child: _RecipeSelectorBody(scrollController: scrollController),
      ),
    ),
  );
}

class _RecipeSelectorBody extends ConsumerStatefulWidget {
  const _RecipeSelectorBody({required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<_RecipeSelectorBody> createState() =>
      _RecipeSelectorBodyState();
}

class _RecipeSelectorBodyState extends ConsumerState<_RecipeSelectorBody> {
  late final UserRecipesNotifier _notifier;

  @override
  void initState() {
    super.initState();
    // Capture the notifier so dispose() can clear sheet-scoped search
    // without touching `ref` after deactivation.
    _notifier = ref.read(userRecipesProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.fetch();
    });
  }

  @override
  void dispose() {
    // Clear sheet-scoped search so the recipes tab isn't pre-filtered.
    _notifier.setQuery(null);
    super.dispose();
  }

  void _openNewRecipe(BuildContext context) {
    Navigator.of(context).pop();
    context.push(RoutePaths.recipeNew);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userRecipesProvider);
    // Snapshot — `build` already re-runs whenever the AsyncValue changes
    // (which happens after every setQuery → fetch round-trip), so a watch
    // on the notifier instance would only add a redundant subscription.
    final hasActiveQuery = _notifier.hasActiveQuery;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppConstants.spacingSm),
        Center(
          child: Container(
            width: AppConstants.dragHandleWidth,
            height: AppConstants.dragHandleHeight,
            decoration: BoxDecoration(
              color: AppTheme.muted,
              borderRadius: BorderRadius.circular(
                AppConstants.dragHandleRadius,
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppConstants.spacingLg,
            AppConstants.spacingMd,
            AppConstants.spacingLg,
            AppConstants.spacingSm,
          ),
          child: Text(
            'Rezept auswählen',
            style: TextStyle(
              fontSize: AppTheme.fontSizeTitle,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
          child: RecipesSearchField(),
        ),
        AppConstants.gap8,
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => const Center(
              child: Text(
                'Konnte Rezepte nicht laden',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  color: AppTheme.mutedForeground,
                ),
              ),
            ),
            data: (recipes) {
              if (recipes.isEmpty) {
                return Center(
                  child: Text(
                    hasActiveQuery ? 'Keine Treffer' : 'Noch keine Rezepte',
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                );
              }
              return ListView.separated(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                ),
                itemCount: recipes.length,
                separatorBuilder: (_, _) => AppConstants.gap8,
                itemBuilder: (context, i) {
                  final recipe = recipes[i];
                  return _RecipeRowCard(
                    recipe: recipe,
                    onTap: () => Navigator.of(context).pop(recipe),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingMd,
            AppConstants.spacingSm,
            AppConstants.spacingMd,
            AppConstants.spacingMd,
          ),
          child: _NewRecipeRow(onTap: () => _openNewRecipe(context)),
        ),
      ],
    );
  }
}

class _RecipeRowCard extends StatelessWidget {
  const _RecipeRowCard({required this.recipe, required this.onTap});

  final UserRecipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SheetRow(
      onTap: onTap,
      leading: _RecipeThumb(recipe: recipe),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            recipe.title.isEmpty ? 'Ohne Namen' : recipe.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          if (recipe.ingredients.isNotEmpty) ...[
            AppConstants.gap4,
            Wrap(
              spacing: AppConstants.spacingXs,
              runSpacing: AppConstants.spacingXs,
              children: [
                for (final ingredient in recipe.ingredients.take(3))
                  _IngredientChip(label: ingredient),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Shared shell for the sheet's tappable rows: a soft-elevated card with
/// a leading widget (thumbnail or icon-badge) and arbitrary content.
class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.onTap,
    required this.leading,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget leading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppConstants.paddingSm,
          child: Row(
            children: [
              leading,
              const SizedBox(width: AppConstants.spacing12),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeThumb extends StatelessWidget {
  const _RecipeThumb({required this.recipe});

  final UserRecipe recipe;

  @override
  Widget build(BuildContext context) {
    if (recipe.imageUrl != null) {
      return SizedBox(
        width: AppConstants.iconBadgeXl,
        height: AppConstants.iconBadgeXl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          child: SignedPathImage(
            pathOrUrl: recipe.imageUrl,
            width: AppConstants.iconBadgeXl,
            height: AppConstants.iconBadgeXl,
            placeholder: Container(color: AppTheme.muted),
            errorWidget: _placeholder(),
          ),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: AppConstants.iconBadgeXl,
      height: AppConstants.iconBadgeXl,
      decoration: BoxDecoration(
        color: pastelForTitle(recipe.title),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.menu_book_outlined,
        color: AppTheme.foreground.withValues(alpha: 0.45),
        size: AppConstants.iconSizeMd,
      ),
    );
  }
}

class _IngredientChip extends StatelessWidget {
  const _IngredientChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacing2,
      ),
      decoration: BoxDecoration(
        color: AppTheme.muted,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: AppTheme.fontSizeCaption,
          color: AppTheme.mutedForeground,
        ),
      ),
    );
  }
}

class _NewRecipeRow extends StatelessWidget {
  const _NewRecipeRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SheetRow(
      onTap: onTap,
      leading: Container(
        width: AppConstants.iconBadgeXl,
        height: AppConstants.iconBadgeXl,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.add, color: AppTheme.primary),
      ),
      child: const Text(
        'Neues Rezept erstellen',
        style: TextStyle(
          fontSize: AppTheme.fontSizeBody,
          fontWeight: FontWeight.w600,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}
