import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../providers/ingredient_suggestion_provider.dart';
import '../../widgets/common/bb_card.dart';

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
    Future.microtask(() => ref.read(ingredientSuggestionProvider.notifier).fetchSuggestions());
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
                  const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (suggestions) {
                final filtered = _searchQuery.isEmpty
                    ? suggestions
                    : suggestions
                        .where((s) =>
                            (s.ingredientName ?? '')
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

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final suggestion = filtered[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Dismissible(
                        key: Key(suggestion.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) {
                          ref
                              .read(ingredientSuggestionProvider.notifier)
                              .dismissSuggestion(suggestion.id);
                        },
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
                          onTap: () {
                            ref
                                .read(ingredientSuggestionProvider.notifier)
                                .markSeen(suggestion.id);
                          },
                          child: BbCard(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            suggestion.ingredientName ?? 'Zutat',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (suggestion.isNew) ...[
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
                                      if (suggestion.helptext != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          suggestion.helptext!,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.mutedForeground,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        'In ${suggestion.mealCount} Mahlzeiten',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    color: AppTheme.mutedForeground),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
