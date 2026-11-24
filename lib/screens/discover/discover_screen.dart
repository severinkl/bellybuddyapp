import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/discover_news_provider.dart';
import '../../providers/ingredient_suggestion_provider.dart';
import '../../providers/knowledge_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/recipe_collection_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../providers/user_recipes_provider.dart';
import '../../router/navigation_extensions.dart';
import '../../router/route_names.dart';
import '../../utils/url_utils.dart';
import 'widgets/discover_alternatives_section.dart';
import 'widgets/discover_knowledge_section.dart';
import 'widgets/discover_recipes_section.dart';
import 'widgets/discover_section.dart';
import 'widgets/discover_tips_card.dart';
import 'widgets/discover_tips_section.dart';
import 'widgets/knowledge_article_tile.dart';

/// The Entdecken tab: the hub over the app's content. Top to bottom:
/// Tipps (the newest recommendation set), Alternativen (the newest
/// ingredient suggestions), Rezepte (Für dich from the collection, and
/// Meine Rezepte: own and saved) and Wissen (the newest myfodmap
/// blog articles).
/// A section with nothing in it says so and links nowhere.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key, this.openUrl = launchUrl});

  /// The Tipps card; opens the Tipps while there are any.
  static const tipsKey = DiscoverTipsCard.cardKey;

  /// The Alternativen section, with its „Alle ›".
  static const alternativesKey = DiscoverAlternativesSection.sectionKey;

  /// The Rezepte section, with its „Alle ›".
  static const recipesKey = DiscoverRecipesSection.sectionKey;

  /// The Wissen section, with its „Alle ›".
  static const knowledgeKey = DiscoverKnowledgeSection.sectionKey;

  /// How a Wissen article opens; tests pass a fake.
  final UrlOpener openUrl;

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  /// Loads tips, alternatives, recipes and articles. The first load keeps
  /// the tips and Alternativen the app root loaded; [refresh] reloads them,
  /// and what is cached (the recipes, the collection with the saved ones,
  /// the articles).
  Future<void> _load({bool refresh = false}) async {
    if (!mounted) return;
    final news = ref.read(discoverNewsProvider.notifier);
    await Future.wait([
      if (refresh) news.refresh() else news.ensureLoaded(),
      ref.read(userRecipesProvider.notifier).fetch(force: refresh),
      if (refresh) ...[
        ref.read(recipeCollectionProvider.notifier).refresh(),
        ref.read(recipeFavoritesProvider.notifier).refresh(),
      ],
      if (refresh)
        ref.read(knowledgeFeedProvider.notifier).refresh()
      else
        ref.read(knowledgeFeedProvider.notifier).refreshIfStale(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final tips = ref.watch(recommendationProvider);
    final weeklyTips = ref.watch(weeklyTipsEnabledProvider);
    final groups = ref.watch(ingredientSuggestionProvider);
    final newGroups = ref.watch(newIngredientSuggestionCountProvider);
    final forYou = ref.watch(forYouRecipesProvider);
    final mine = ref.watch(myRecipeItemsProvider);
    final knowledge = ref.watch(knowledgeFeedProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Entdecken')),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        color: AppTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingMd,
            AppConstants.spacingSm,
            AppConstants.spacingMd,
            AppConstants.spacingLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DiscoverSection(
                title: 'Tipps',
                child: DiscoverTipsSection(
                  tips: tips,
                  weeklyTips: weeklyTips,
                  onOpen: () => context.push(RoutePaths.recommendations),
                ),
              ),
              AppConstants.gap24,
              DiscoverAlternativesSection(
                groups: groups,
                newCount: newGroups,
                onOpen: () => context.push(RoutePaths.ingredientSuggestions),
              ),
              AppConstants.gap24,
              DiscoverRecipesSection(
                forYou: forYou,
                mine: mine,
                onOpenAll: () => context.push(RoutePaths.discoverRecipes),
                onOpenMine: () => context.push(RoutePaths.recipes),
                onOpenRecipe: (id) => unawaited(context.openRecipe(id)),
                onOpenOwn: (recipe) =>
                    context.push(RoutePaths.recipeDetailFor(recipe.id)),
              ),
              AppConstants.gap24,
              DiscoverKnowledgeSection(
                feed: knowledge,
                onOpenAll: () => context.push(RoutePaths.knowledge),
                onOpen: (article) => unawaited(
                  openArticle(context, article, open: widget.openUrl),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
