import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_theme.dart';
import '../../providers/recipes_provider.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/bb_card.dart';
import 'widgets/recipe_detail_sheet.dart';

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recipesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rezepte')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                // Search
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Rezept suchen...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) =>
                        ref.read(recipesProvider.notifier).setSearch(v),
                  ),
                ),
                // Filters
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Vegetarisch', 'Vegan', 'Glutenfrei', 'Laktosefrei']
                          .map((tag) {
                        final isActive = state.filters.contains(tag);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(tag),
                            selected: isActive,
                            onSelected: (_) =>
                                ref.read(recipesProvider.notifier).toggleFilter(tag),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: state.filtered.length,
                    itemBuilder: (context, index) {
                      final recipe = state.filtered[index];
                      final isFav = state.favorites.contains(recipe.id);
                      return GestureDetector(
                        onTap: () => RecipeDetailSheet.show(context, recipe),
                        child: BbCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    if (recipe.imageUrl != null)
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(16)),
                                        child: CachedNetworkImage(
                                          imageUrl: StorageService.getPublicUrl(
                                            bucket: 'recipe-images',
                                            path: recipe.imageUrl!,
                                          ),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          placeholder: (_, _) => Container(
                                            color: AppTheme.muted,
                                          ),
                                          errorWidget: (_, _, _) => Container(
                                            color: AppTheme.muted,
                                            child: const Icon(Icons.restaurant),
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppTheme.muted,
                                          borderRadius: const BorderRadius.vertical(
                                              top: Radius.circular(16)),
                                        ),
                                        child: const Center(
                                          child: Icon(Icons.restaurant, size: 40),
                                        ),
                                      ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () => ref
                                            .read(recipesProvider.notifier)
                                            .toggleFavorite(recipe.id),
                                        child: Icon(
                                          isFav ? Icons.favorite : Icons.favorite_border,
                                          color: isFav ? AppTheme.destructive : Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      recipe.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (recipe.cookTime != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '${recipe.cookTime} Min.',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
