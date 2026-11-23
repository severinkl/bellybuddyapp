import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/ingredient_suggestion_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../providers/user_recipes_provider.dart';
import '../../router/route_names.dart';
import '../../utils/url_utils.dart';
import 'widgets/discover_alternatives_section.dart';
import 'widgets/discover_knowledge_card.dart';
import 'widgets/discover_recipes_section.dart';
import 'widgets/discover_section.dart';
import 'widgets/discover_tips_card.dart';

/// The Entdecken tab: the hub over the app's content. Top to bottom:
/// Tipps (the newest recommendation set), Alternativen (the newest
/// ingredient suggestions), Meine Rezepte and Wissen (the myfodmap blog).
/// A section with nothing in it says so and links nowhere.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key, this.openUrl = launchUrl});

  /// The Tipps card; opens the Tipps while there are any.
  static const tipsKey = DiscoverTipsCard.cardKey;

  /// The Alternativen section, with its „Alle ›".
  static const alternativesKey = DiscoverAlternativesSection.sectionKey;

  /// The Meine Rezepte section, with its „+" and „Alle ›".
  static const recipesKey = DiscoverRecipesSection.sectionKey;

  /// The Wissen card; opens the blog.
  static const knowledgeKey = DiscoverKnowledgeCard.cardKey;

  /// How the Wissen card opens the blog; tests pass a fake.
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

  Future<void> _openBlog() => openExternalUrl(
    context,
    AppConstants.blogUrl,
    failureMessage: 'Der Blog konnte nicht geöffnet werden.',
    open: widget.openUrl,
  );

  @override
  Widget build(BuildContext context) {
    // More unseen tips than before (a tips push refreshed the count): a new
    // set arrived, so load it, or „Neu" would mark the previous one.
    ref.listen<AsyncValue<int>>(unseenRecommendationCountProvider, (
      previous,
      next,
    ) {
      final before = previous?.value;
      if (before != null && (next.value ?? 0) > before) {
        unawaited(
          ref.read(recommendationProvider.notifier).fetchRecommendations(),
        );
      }
    });
    final tips = ref.watch(recommendationProvider);
    final unseenTips = ref.watch(unseenRecommendationCountProvider).value ?? 0;
    final groups = ref.watch(ingredientSuggestionProvider);
    final newGroups = ref.watch(newIngredientSuggestionCountProvider);
    final recipes = ref.watch(userRecipesProvider);

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
                child: DiscoverTipsCard(
                  tips: tips,
                  unseen: unseenTips > 0,
                  onTap: () => context.push(RoutePaths.recommendations),
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
                recipes: recipes,
                onOpenAll: () => context.push(RoutePaths.recipes),
                onOpen: (recipe) =>
                    context.push(RoutePaths.recipeDetailFor(recipe.id)),
              ),
              AppConstants.gap24,
              DiscoverSection(
                title: 'Wissen',
                child: DiscoverKnowledgeCard(onTap: _openBlog),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
