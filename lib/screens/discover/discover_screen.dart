import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/ingredient_suggestion_group.dart';
import '../../models/recommendation.dart';
import '../../models/user_recipe.dart';
import '../../providers/ingredient_suggestion_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../providers/user_recipes_provider.dart';
import '../../router/route_names.dart';
import '../../utils/date_format_utils.dart';
import '../../utils/url_utils.dart';
import '../../widgets/common/bb_card.dart';
import '../recipes/widgets/add_recipe_chooser_sheet.dart';
import '../recipes/widgets/recipe_card.dart';
import 'widgets/discover_section.dart';

/// The Entdecken tab: the hub over the app's content. Top to bottom:
/// Tipps (the newest recommendation set), Alternativen (the newest
/// ingredient suggestions), Meine Rezepte and Wissen (the myfodmap blog).
/// A section with nothing in it says so and links nowhere.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key, this.openUrl = launchUrl});

  /// The Tipps card; opens the Tipps while there are any.
  static const tipsKey = Key('discover_tips');

  /// The Alternativen section, with its „Alle ›".
  static const alternativesKey = Key('discover_alternatives');

  /// The Meine Rezepte section, with its „+" and „Alle ›".
  static const recipesKey = Key('discover_recipes');

  /// The Wissen card; opens the blog.
  static const knowledgeKey = Key('discover_knowledge');

  /// How the Wissen card opens the blog; tests pass a fake.
  final UrlOpener openUrl;

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  static const _alternativesShown = 3;
  static const _recipesShown = 6;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  /// Loads tips, alternatives and recipes; [refresh] also reloads what is
  /// cached (the recipes and the unseen-tips count).
  Future<void> _load({bool refresh = false}) async {
    if (!mounted) return;
    if (refresh) ref.invalidate(unseenRecommendationCountProvider);
    await Future.wait([
      ref.read(recommendationProvider.notifier).fetchRecommendations(),
      ref.read(ingredientSuggestionProvider.notifier).fetchSuggestions(),
      ref.read(userRecipesProvider.notifier).fetch(force: refresh),
    ]);
  }

  /// Pushes [path]; back here, rebuilds, since the Alternativen screen marks
  /// its suggestions seen without a state change („n neu" reads it).
  Future<void> _open(String path) async {
    await context.push(path);
    if (mounted) setState(() {});
  }

  Future<void> _openBlog() => openExternalUrl(
    context,
    AppConstants.blogUrl,
    failureMessage: 'Der Blog konnte nicht geöffnet werden.',
    open: widget.openUrl,
  );

  @override
  Widget build(BuildContext context) {
    final tips = ref.watch(recommendationProvider);
    final unseenTips = ref.watch(unseenRecommendationCountProvider).value ?? 0;
    final groups = ref.watch(ingredientSuggestionProvider);
    final newGroups = ref.read(ingredientSuggestionProvider.notifier).newCount;
    final recipes = ref.watch(userRecipesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Entdecken')),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        color: AppTheme.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingMd,
                AppConstants.spacingSm,
                AppConstants.spacingMd,
                AppConstants.spacingLg,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DiscoverSection(
                      title: 'Tipps',
                      child: _TipsCard(
                        tips: tips,
                        unseen: unseenTips > 0,
                        onTap: () => _open(RoutePaths.recommendations),
                      ),
                    ),
                    AppConstants.gap24,
                    _AlternativesSection(
                      groups: groups,
                      newCount: newGroups,
                      onOpen: () => _open(RoutePaths.ingredientSuggestions),
                      shown: _alternativesShown,
                    ),
                    AppConstants.gap24,
                    _RecipesSection(
                      recipes: recipes,
                      shown: _recipesShown,
                      onOpenAll: () => _open(RoutePaths.recipes),
                      onOpen: (recipe) =>
                          _open(RoutePaths.recipeDetailFor(recipe.id)),
                    ),
                    AppConstants.gap24,
                    DiscoverSection(
                      title: 'Wissen',
                      child: _KnowledgeCard(onTap: _openBlog),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The newest tip set: „Neu" while unseen, its ISO week, how many tips,
/// two lines of its summary. No tips: a line, not tappable.
class _TipsCard extends StatelessWidget {
  const _TipsCard({
    required this.tips,
    required this.unseen,
    required this.onTap,
  });

  final AsyncValue<List<Recommendation>> tips;
  final bool unseen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final list = tips.value;
    if (list == null) {
      return DiscoverNote(
        key: DiscoverScreen.tipsKey,
        tips.hasError ? 'Tipps konnten nicht geladen werden.' : 'Laden…',
      );
    }
    if (list.isEmpty) {
      return const DiscoverNote(
        key: DiscoverScreen.tipsKey,
        'Noch keine Tipps.',
      );
    }
    // The list is newest first.
    final newest = list.first;
    final createdAt = newest.createdAt;
    final count = newest.recommendations.length;
    final summary = newest.summary?.trim() ?? '';
    return Semantics(
      button: true,
      child: BbCard(
        key: DiscoverScreen.tipsKey,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (unseen) ...[
                  const DiscoverPill('Neu'),
                  const SizedBox(width: AppConstants.spacingSm),
                ],
                Expanded(
                  child: Text(
                    createdAt == null
                        ? 'Deine Tipps'
                        : 'Woche ${isoWeekOf(createdAt.toLocal())}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeSubtitle,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                    ),
                  ),
                ),
                Text(
                  count == 1 ? '1 Tipp' : '$count Tipps',
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeCaptionLG,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.mutedForeground,
                ),
              ],
            ),
            if (summary.isNotEmpty) ...[
              AppConstants.gap6,
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  color: AppTheme.mutedForeground,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The newest [shown] suggestion groups (unseen first, then by their
/// latest meal) and „Alle ›"; none: a line and no link.
class _AlternativesSection extends StatelessWidget {
  const _AlternativesSection({
    required this.groups,
    required this.newCount,
    required this.onOpen,
    required this.shown,
  });

  final AsyncValue<List<IngredientSuggestionGroup>> groups;
  final int newCount;
  final VoidCallback onOpen;
  final int shown;

  /// When the group's latest meal was eaten; null without meals.
  static DateTime? _latestMeal(IngredientSuggestionGroup g) {
    DateTime? latest;
    for (final meal in g.meals) {
      if (latest == null || meal.trackedAt.isAfter(latest)) {
        latest = meal.trackedAt;
      }
    }
    return latest;
  }

  static List<IngredientSuggestionGroup> _newest(
    List<IngredientSuggestionGroup> groups,
    int count,
  ) {
    final latest = {for (final g in groups) g: _latestMeal(g)};
    int byNewest(IngredientSuggestionGroup a, IngredientSuggestionGroup b) {
      if (a.isNew != b.isNew) return a.isNew ? -1 : 1;
      final la = latest[a];
      final lb = latest[b];
      if (la != lb) {
        if (la == null) return 1;
        if (lb == null) return -1;
        return lb.compareTo(la);
      }
      return a.ingredientName.toLowerCase().compareTo(
        b.ingredientName.toLowerCase(),
      );
    }

    return ([...groups]..sort(byNewest)).take(count).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = groups.value;
    final hasAny = list != null && list.isNotEmpty;
    return DiscoverSection(
      key: DiscoverScreen.alternativesKey,
      title: 'Alternativen',
      badge: newCount > 0 ? '$newCount neu' : null,
      actions: [if (hasAny) DiscoverAllLink(onTap: onOpen)],
      child: switch (list) {
        null => DiscoverNote(
          groups.hasError
              ? 'Alternativen konnten nicht geladen werden.'
              : 'Laden…',
        ),
        [] => const DiscoverNote(
          'Noch keine Alternativen – sie entstehen nach deinen Mahlzeiten.',
        ),
        final items => Semantics(
          button: true,
          child: BbCard(
            onTap: onOpen,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingXs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, group) in _newest(items, shown).indexed) ...[
                  if (i > 0)
                    const Divider(
                      height: AppConstants.dividerThickness,
                      thickness: AppConstants.dividerThickness,
                      color: AppTheme.border,
                    ),
                  _AlternativeRow(group: group),
                ],
              ],
            ),
          ),
        ),
      },
    );
  }
}

/// A suggestion group's ingredient and what can replace it.
class _AlternativeRow extends StatelessWidget {
  const _AlternativeRow({required this.group});

  final IngredientSuggestionGroup group;

  @override
  Widget build(BuildContext context) {
    final replacements = group.replacements.map((r) => r.name).join(', ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacing10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.ingredientName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBodyLG,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          if (replacements.isNotEmpty) ...[
            AppConstants.gap4,
            Text(
              'Stattdessen: $replacements',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeCaptionLG,
                color: AppTheme.mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Up to [shown] of the user's recipes in a row, „+" and „Alle ›"; none:
/// a line and „Erstes Rezept erstellen".
class _RecipesSection extends StatelessWidget {
  const _RecipesSection({
    required this.recipes,
    required this.shown,
    required this.onOpenAll,
    required this.onOpen,
  });

  final AsyncValue<List<UserRecipe>> recipes;
  final int shown;
  final VoidCallback onOpenAll;
  final ValueChanged<UserRecipe> onOpen;

  @override
  Widget build(BuildContext context) {
    final list = recipes.value;
    final hasAny = list != null && list.isNotEmpty;
    return DiscoverSection(
      key: DiscoverScreen.recipesKey,
      title: 'Meine Rezepte',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Rezept hinzufügen',
          onPressed: () => showAddRecipeChooserSheet(context),
        ),
        if (hasAny) DiscoverAllLink(onTap: onOpenAll),
      ],
      child: switch (list) {
        null => DiscoverNote(
          recipes.hasError ? 'Rezepte konnten nicht geladen werden.' : 'Laden…',
        ),
        [] => BbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Noch keine Rezepte.',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  color: AppTheme.mutedForeground,
                ),
              ),
              AppConstants.gap12,
              FilledButton(
                onPressed: () => showAddRecipeChooserSheet(context),
                child: const Text('Erstes Rezept erstellen'),
              ),
            ],
          ),
        ),
        final items => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, recipe) in items.take(shown).indexed) ...[
                  if (i > 0) const SizedBox(width: AppConstants.spacingSm),
                  SizedBox(
                    width: AppConstants.discoverRecipeCardWidth,
                    child: RecipeCard(
                      recipe: recipe,
                      onTap: () => onOpen(recipe),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      },
    );
  }
}

/// Opens the myfodmap blog in the browser.
class _KnowledgeCard extends StatelessWidget {
  const _KnowledgeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: BbCard(
        key: DiscoverScreen.knowledgeKey,
        onTap: onTap,
        child: const Row(
          children: [
            Icon(Icons.menu_book_outlined, color: AppTheme.foreground),
            SizedBox(width: AppConstants.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wissen rund um die Verdauung',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBodyLG,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                  ),
                  AppConstants.gap4,
                  Text(
                    'Artikel aus dem myfodmap-Blog',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeCaptionLG,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: AppConstants.spacingSm),
            Icon(Icons.open_in_new, color: AppTheme.mutedForeground),
          ],
        ),
      ),
    );
  }
}
