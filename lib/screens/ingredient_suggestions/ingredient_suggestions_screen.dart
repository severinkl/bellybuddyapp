import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../models/ingredient_suggestion_group.dart';
import '../../providers/ingredient_suggestion_provider.dart';
import '../../widgets/common/bb_async_state.dart';
import 'widgets/suggestion_card.dart';
import 'widgets/suggestion_detail_modal.dart';
import '../../config/constants.dart';

class IngredientSuggestionsScreen extends ConsumerStatefulWidget {
  const IngredientSuggestionsScreen({super.key});

  @override
  ConsumerState<IngredientSuggestionsScreen> createState() =>
      _IngredientSuggestionsScreenState();
}

class _IngredientSuggestionsScreenState
    extends ConsumerState<IngredientSuggestionsScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final notifier = ref.read(ingredientSuggestionProvider.notifier);
      await notifier.fetchSuggestions();
      await notifier.markAllNewAsSeen();
    });
  }

  /// Prefetch valid http(s) image URLs into the CachedNetworkImage cache.
  /// Meal image paths are skipped — they require async signed URL resolution
  /// which is handled by MealThumbnail at render time.
  void _precacheImages(List<IngredientSuggestionGroup> groups) {
    for (final group in groups) {
      final urls = <String>[
        if (group.ingredientImageUrl != null &&
            group.ingredientImageUrl!.isNotEmpty)
          group.ingredientImageUrl!,
        ...group.replacements
            .where((r) => r.imageUrl != null && r.imageUrl!.isNotEmpty)
            .map((r) => r.imageUrl!),
      ];
      for (final url in urls) {
        if (url.startsWith('https://') || url.startsWith('http://')) {
          precacheImage(CachedNetworkImageProvider(url), context);
        }
      }
    }
  }

  void _openDetail(IngredientSuggestionGroup group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SuggestionDetailModal(group: group),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ingredientSuggestionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Zutaten-Vorschläge')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Suchen...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: state.when(
              loading: () =>
                  const BbLoadingState(message: 'Vorschläge laden...'),
              error: (e, _) => BbErrorState(
                message: 'Fehler beim Laden der Vorschläge.',
                onRetry: () => ref
                    .read(ingredientSuggestionProvider.notifier)
                    .fetchSuggestions(),
              ),
              data: (groups) {
                _precacheImages(groups);
                final filtered = _searchQuery.isEmpty
                    ? groups
                    : groups
                          .where(
                            (g) => g.ingredientName.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ),
                          )
                          .toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: AppConstants.paddingLg,
                      child: Text(
                        'Keine Vorschläge vorhanden.',
                        style: TextStyle(color: AppTheme.mutedForeground),
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(
                        '${filtered.length} ${filtered.length == 1 ? 'Vorschlag' : 'Vorschläge'}',
                        style: const TextStyle(
                          fontSize: AppTheme.fontSizeCaptionLG,
                          color: AppTheme.mutedForeground,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final group = filtered[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SuggestionCard(
                              group: group,
                              onTap: () => _openDetail(group),
                              onDismiss: () {
                                ref
                                    .read(ingredientSuggestionProvider.notifier)
                                    .dismissSuggestion(group.suggestionIds);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
