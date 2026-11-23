import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ingredient_suggestion_group.dart';
import '../providers/core_providers.dart';
import '../repositories/ingredient_repository.dart';
import '../utils/logger.dart';

class IngredientSuggestionNotifier
    extends Notifier<AsyncValue<List<IngredientSuggestionGroup>>> {
  static const _log = AppLogger('IngredientSuggestions');

  /// The suggestion ids [markAllNewAsSeen] stored as seen. A fetch that
  /// started before the server stored them still has their groups new;
  /// [newIngredientSuggestionCountProvider] counts those no more.
  final _seenIds = <String>{};

  @override
  AsyncValue<List<IngredientSuggestionGroup>> build() {
    _seenIds.clear();
    return const AsyncValue.loading();
  }

  /// Loads the groups; while some are loaded, they stay until the new ones
  /// are in.
  Future<void> fetchSuggestions() async {
    if (!state.hasValue) state = const AsyncValue.loading();
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      final repo = ref.read(ingredientRepositoryProvider);
      final groups = await repo.fetchSuggestionGroups(userId);
      if (_isCurrentUser(userId)) state = AsyncValue.data(groups);
    } catch (e, st) {
      _log.error('fetchSuggestions failed', e, st);
      if (_isCurrentUser(userId)) state = AsyncValue.error(e, st);
    }
  }

  /// Whether [userId] is still the signed-in user after an await; what was
  /// fetched for the previous one is dropped.
  bool _isCurrentUser(String userId) =>
      ref.mounted && ref.read(currentUserIdProvider) == userId;

  /// Marks the new groups seen in the backend. The list keeps their
  /// `isNew` (the Alternativen screen still shows „Neu" while open), but
  /// [newIngredientSuggestionCountProvider] no longer counts them once the
  /// server has stored it.
  Future<void> markAllNewAsSeen() async {
    final groups = state.whenOrNull(data: (g) => g);
    if (groups == null) return;

    final unseenIds = groups
        .where((g) => g.isNew)
        .expand((g) => g.suggestionIds)
        .toList();
    if (unseenIds.isEmpty) return;

    try {
      await ref.read(ingredientRepositoryProvider).markAllSeen(unseenIds);
      if (!ref.mounted) return;
      _seenIds.addAll(unseenIds);
      // The list is unchanged; tell the count it changed.
      ref.notifyListeners();
    } catch (e, st) {
      _log.error('markAllNewAsSeen failed', e, st);
    }
  }

  Future<void> dismissSuggestion(List<String> ids) async {
    try {
      await ref.read(ingredientRepositoryProvider).dismissSuggestions(ids);
      final idsSet = ids.toSet();
      state = state.whenData(
        (groups) =>
            groups.where((g) => !g.suggestionIds.any(idsSet.contains)).toList(),
      );
    } catch (e, st) {
      _log.error('dismissSuggestion failed', e, st);
    }
  }
}

final ingredientSuggestionProvider =
    NotifierProvider<
      IngredientSuggestionNotifier,
      AsyncValue<List<IngredientSuggestionGroup>>
    >(IngredientSuggestionNotifier.new);

/// How many suggestion groups are new, for Entdecken's „n neu": 0 while
/// loading or failed. A group [IngredientSuggestionNotifier.markAllNewAsSeen]
/// marked seen counts no more, even if a fetch from before the mark still
/// has it new; one with a suggestion added since counts again.
final newIngredientSuggestionCountProvider = Provider<int>((ref) {
  final groups = ref.watch(ingredientSuggestionProvider);
  final seen = ref.read(ingredientSuggestionProvider.notifier)._seenIds;
  return groups.whenOrNull(
        data: (list) => list
            .where((g) => g.isNew && !g.suggestionIds.every(seen.contains))
            .length,
      ) ??
      0;
});
