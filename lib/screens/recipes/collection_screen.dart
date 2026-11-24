import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/recipe.dart';
import '../../providers/recipe_collection_provider.dart';
import '../../router/navigation_extensions.dart';
import '../../router/route_names.dart';
import '../../services/recipes/recipe_copy.dart';
import '../../services/recipes/recipe_ranking.dart';
import '../../widgets/common/bb_async_state.dart';
import '../../widgets/common/bb_chip_selector.dart';
import 'widgets/recipe_list_tile.dart';

/// Rezepte: the whole collection, ranked for the user, with a meal filter,
/// „Passt zu mir" and a search.
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  static const searchKey = Key('collection_search');
  static const fitToggleKey = Key('collection_fit');
  static Key chipKey(MealType t) => ValueKey('collection_chip_${t.key}');

  static const empty =
      'Keine Rezepte gefunden. Probier einen anderen Filter oder Suchbegriff.';

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  /// Held here: the lazy list drops the field once it scrolls away, and the
  /// query it filters by must still show when it comes back.
  final _search = TextEditingController();
  String _query = '';
  MealType? _mealType;
  bool _fitsOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() =>
      ref.read(recipeCollectionProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(rankedRecipesProvider);
    final ranked = async.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rezepte'),
        leading: BackButton(
          onPressed: () => context.popOr(RoutePaths.discover),
        ),
      ),
      body: ranked != null
          ? _buildList(ranked)
          : async.hasError
          ? BbErrorState(
              message: 'Rezepte konnten nicht geladen werden.',
              onRetry: () => unawaited(_refresh()),
            )
          : const BbLoadingState(message: 'Laden…'),
    );
  }

  Widget _buildList(RankedRecipes ranked) {
    // Without the table there is nothing to filter by.
    final fitsOnly = _fitsOnly && ranked.checked;
    final fits = filterRecipes(
      ranked.fits,
      query: _query,
      mealType: _mealType,
      fitsOnly: fitsOnly,
    );
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Scrolling the results puts the search's keyboard away.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: AppConstants.paddingMd,
        children: [
          TextField(
            key: CollectionScreen.searchKey,
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Rezept oder Zutat suchen',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppTheme.card,
              border: _pillBorder,
              enabledBorder: _pillBorder,
              focusedBorder: _pillBorder,
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          AppConstants.gap12,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in MealType.values) ...[
                  BbFilterChip(
                    key: CollectionScreen.chipKey(t),
                    label: t.label,
                    selected: t == _mealType,
                    onSelected: (on) =>
                        setState(() => _mealType = on ? t : null),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                ],
              ],
            ),
          ),
          if (ranked.checked) ...[
            SwitchListTile(
              key: CollectionScreen.fitToggleKey,
              title: const Text('Passt zu mir'),
              subtitle: const Text('Nur Rezepte ohne kritische Zutaten'),
              value: fitsOnly,
              activeThumbColor: AppTheme.primary,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _fitsOnly = v),
            ),
            if (ranked.selfCheck.isNotEmpty)
              Text(
                RecipeCopy.selfCheckFilter(ranked.selfCheck),
                style: AppTheme.captionMutedStyle,
              ),
          ],
          AppConstants.gap8,
          Text(
            _countLine(fits.length, ranked),
            style: AppTheme.captionMutedStyle,
          ),
          AppConstants.gap8,
          if (fits.isEmpty)
            const Padding(
              padding: AppConstants.paddingLg,
              child: Text(
                CollectionScreen.empty,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBodyLG,
                  color: AppTheme.mutedForeground,
                ),
              ),
            ),
          for (final fit in fits)
            Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
              child: RecipeListTile(
                recipe: fit.recipe,
                badge: fit.badge,
                onTap: () => unawaited(context.openRecipe(fit.recipe.id)),
              ),
            ),
        ],
      ),
    );
  }

  static String _countLine(int count, RankedRecipes ranked) {
    final diet = switch (ranked.diet) {
      'vegan' when ranked.hiddenByDiet > 0 => 'vegane',
      'vegetarisch' when ranked.hiddenByDiet > 0 => 'vegetarische',
      _ => null,
    };
    return [
      count == 1 ? '1 Rezept' : '$count Rezepte',
      'für dich sortiert',
      ?(diet == null ? null : 'nur $diet, wie in deinem Profil'),
    ].join(' · ');
  }

  static final _pillBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppConstants.radiusRound),
    borderSide: BorderSide.none,
  );
}
