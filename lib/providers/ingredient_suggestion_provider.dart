import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ingredient_suggestion_group.dart';
import '../providers/core_providers.dart';
import '../repositories/ingredient_repository.dart';
import '../utils/logger.dart';

class IngredientSuggestionNotifier
    extends Notifier<AsyncValue<List<IngredientSuggestionGroup>>> {
  static const _log = AppLogger('IngredientSuggestions');

  /// Whether [markAllNewAsSeen] marked the loaded groups seen;
  /// [newIngredientSuggestionCountProvider] is 0 then. Cleared when groups
  /// load again: the server no longer marks the seen ones new, so what is
  /// new then is new since.
  bool _markedSeen = false;

  @override
  AsyncValue<List<IngredientSuggestionGroup>> build() =>
      const AsyncValue.loading();

  Future<void> fetchSuggestions() async {
    state = const AsyncValue.loading();
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final repo = ref.read(ingredientRepositoryProvider);
      final groups = await repo.fetchSuggestionGroups(userId);
      _markedSeen = false;
      state = AsyncValue.data(groups);
    } catch (e, st) {
      _log.error('fetchSuggestions failed', e, st);
      state = AsyncValue.error(e, st);
    }
  }

  /// Marks the new groups seen in the backend. The list keeps their
  /// `isNew` (the Alternativen screen still shows „Neu" while open), but
  /// [newIngredientSuggestionCountProvider] drops to 0.
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
      _markedSeen = true;
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
/// loading or failed, and once [IngredientSuggestionNotifier.markAllNewAsSeen]
/// marked them seen, until groups load again.
final newIngredientSuggestionCountProvider = Provider<int>((ref) {
  final groups = ref.watch(ingredientSuggestionProvider);
  if (ref.read(ingredientSuggestionProvider.notifier)._markedSeen) {
    return 0;
  }
  return groups.whenOrNull(data: (list) => list.where((g) => g.isNew).length) ??
      0;
});
