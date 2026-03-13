import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/bb_card.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _filtered = [];
  Set<String> _favorites = {};
  bool _isLoading = true;
  String _search = '';
  final _filters = <String>{};

  @override
  void initState() {
    super.initState();
    _loadRecipes();
    _loadFavorites();
  }

  Future<void> _loadRecipes() async {
    try {
      final data = await SupabaseService.client
          .from('recipes')
          .select()
          .order('title');
      setState(() {
        _recipes = List<Map<String, dynamic>>.from(data);
        _filtered = _recipes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFavorites() async {
    final userId = SupabaseService.userId;
    if (userId == null) return;
    try {
      final data = await SupabaseService.client
          .from('user_favorite_recipes')
          .select('recipe_id')
          .eq('user_id', userId);
      setState(() {
        _favorites = (data as List).map((e) => e['recipe_id'] as String).toSet();
      });
    } catch (_) {}
  }

  Future<void> _toggleFavorite(String recipeId) async {
    final userId = SupabaseService.userId;
    if (userId == null) return;
    if (_favorites.contains(recipeId)) {
      await SupabaseService.client
          .from('user_favorite_recipes')
          .delete()
          .eq('user_id', userId)
          .eq('recipe_id', recipeId);
      setState(() => _favorites.remove(recipeId));
    } else {
      await SupabaseService.client
          .from('user_favorite_recipes')
          .insert({'user_id': userId, 'recipe_id': recipeId});
      setState(() => _favorites.add(recipeId));
    }
  }

  void _applyFilters() {
    setState(() {
      _filtered = _recipes.where((r) {
        final title = (r['title'] as String? ?? '').toLowerCase();
        final tags = List<String>.from(r['tags'] ?? []);
        final matchesSearch = _search.isEmpty || title.contains(_search.toLowerCase());
        final matchesFilters = _filters.isEmpty || _filters.every((f) => tags.contains(f));
        return matchesSearch && matchesFilters;
      }).toList();
    });
  }

  void _showRecipeDetail(Map<String, dynamic> recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.muted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                recipe['title'] ?? '',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              if (recipe['description'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  recipe['description'],
                  style: const TextStyle(color: AppTheme.mutedForeground),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (recipe['cook_time'] != null)
                    _infoChip(Icons.access_time, '${recipe['cook_time']} Min.'),
                  if (recipe['servings'] != null)
                    _infoChip(Icons.people, '${recipe['servings']} Port.'),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Zutaten', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...List<String>.from(recipe['ingredients'] ?? []).map(
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $i', style: const TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Zubereitung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...List<String>.from(recipe['instructions'] ?? []).asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${e.key + 1}. ${e.value}', style: const TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.secondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.mutedForeground),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.foreground)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rezepte')),
      body: _isLoading
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
                    onChanged: (v) {
                      _search = v;
                      _applyFilters();
                    },
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
                        final isActive = _filters.contains(tag);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(tag),
                            selected: isActive,
                            onSelected: (v) {
                              if (v) {
                                _filters.add(tag);
                              } else {
                                _filters.remove(tag);
                              }
                              _applyFilters();
                            },
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
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final recipe = _filtered[index];
                      final isFav = _favorites.contains(recipe['id']);
                      return GestureDetector(
                        onTap: () => _showRecipeDetail(recipe),
                        child: BbCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    if (recipe['image_url'] != null)
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(16)),
                                        child: CachedNetworkImage(
                                          imageUrl: StorageService.getPublicUrl(
                                            bucket: 'recipe-images',
                                            path: recipe['image_url'],
                                          ),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          placeholder: (_, __) => Container(
                                            color: AppTheme.muted,
                                          ),
                                          errorWidget: (_, __, ___) => Container(
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
                                        onTap: () => _toggleFavorite(recipe['id']),
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
                                      recipe['title'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (recipe['cook_time'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '${recipe['cook_time']} Min.',
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
