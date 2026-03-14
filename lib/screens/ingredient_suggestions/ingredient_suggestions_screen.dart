import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../models/ingredient_suggestion_group.dart';
import '../../providers/ingredient_suggestion_provider.dart';
import '../../widgets/common/bb_card.dart';
import 'widgets/suggestion_detail_modal.dart';

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
              loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.primary)),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (groups) {
                final filtered = _searchQuery.isEmpty
                    ? groups
                    : groups
                        .where((g) => g.ingredientName
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()))
                        .toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
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
                          fontSize: 13,
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
                            child: _SuggestionCard(
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

class _SuggestionCard extends StatelessWidget {
  final IngredientSuggestionGroup group;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _SuggestionCard({
    required this.group,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(group.ingredientId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.muted,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.close, color: AppTheme.mutedForeground),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: BbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Ingredient image
                  _IngredientAvatar(imageUrl: group.ingredientImageUrl),
                  const SizedBox(width: 12),
                  // Name + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                group.ingredientName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (group.isNew) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Neu',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primaryForeground,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'gefunden in ${group.mealCount} ${group.mealCount == 1 ? 'Speise' : 'Speisen'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Info icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.muted,
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ],
              ),
              // Alternatives horizontal scroll
              if (group.replacements.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: group.replacements.length,
                    separatorBuilder: (c, i) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final repl = group.replacements[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.beige,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (repl.imageUrl != null &&
                                repl.imageUrl!.isNotEmpty) ...[
                              ClipOval(
                                child: Image.network(
                                  repl.imageUrl!,
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) =>
                                      const Text('\u{1F96C}',
                                          style: TextStyle(fontSize: 14)),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              repl.name,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.foreground,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IngredientAvatar extends StatelessWidget {
  final String? imageUrl;

  const _IngredientAvatar({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: AppTheme.muted,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text('\u{1F96C}', style: TextStyle(fontSize: 22)),
      ),
    );
  }
}
