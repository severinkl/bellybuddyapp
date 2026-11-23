import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ingredient_suggestion_group.dart';
import '../repositories/ingredient_repository.dart';
import '../utils/coalesced_runner.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';

class IngredientSuggestionNotifier
    extends Notifier<AsyncValue<List<IngredientSuggestionGroup>>> {
  static const _log = AppLogger('IngredientSuggestions');

  /// The suggestion ids [markAllNewAsSeen] stored as seen. A fetch that
  /// started before the server stored them still has their groups new;
  /// [newIngredientSuggestionCountProvider] counts those no more.
  final _seenIds = <String>{};

  /// The loads, coalesced per user.
  final _fetches = CoalescedRunner();

  @override
  AsyncValue<List<IngredientSuggestionGroup>> build() {
    _seenIds.clear();
    return const AsyncValue.loading();
  }

  /// Loads the groups; while some are loaded, they stay until the new ones
  /// are in. A failed reload keeps them as they are (it is only logged), so
  /// an offline resume blanks neither the open Alternativen nor Entdecken;
  /// only a first load shows the error.
  ///
  /// Coalesced per user: a call while a load runs (a push, a pull to
  /// refresh, a screen opening) makes exactly one more after it and
  /// completes once that one is done. Never throws.
  Future<void> fetchSuggestions() {
    final userId = ref.read(currentUserIdProvider);
    return _fetches.run(key: userId, () => _fetch(userId));
  }

  Future<void> _fetch(String? userId) async {
    if (!state.hasValue) state = const AsyncValue.loading();
    if (userId == null) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      final repo = ref.read(ingredientRepositoryProvider);
      final groups = await repo.fetchSuggestionGroups(userId);
      if (ref.isCurrentUser(userId)) state = AsyncValue.data(groups);
    } catch (e, st) {
      _log.error('fetchSuggestions failed', e, st);
      if (ref.isCurrentUser(userId) && !state.hasValue) {
        state = AsyncValue.error(e, st);
      }
    }
  }

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
  final groups = ref.watch(ingredientSuggestionProvider).value ?? const [];
  final seen = ref.read(ingredientSuggestionProvider.notifier)._seenIds;
  return groups
      .where((g) => g.isNew && !g.suggestionIds.every(seen.contains))
      .length;
});
