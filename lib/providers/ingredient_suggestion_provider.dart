import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ingredient_suggestion_group.dart';
import '../repositories/ingredient_repository.dart';
import '../services/alternatives/alternative_ranking.dart';
import '../utils/coalesced_runner.dart';
import '../utils/logger.dart';
import 'alternative_choices_provider.dart';
import 'auth_provider.dart';

class IngredientSuggestionNotifier
    extends Notifier<AsyncValue<List<IngredientSuggestionGroup>>> {
  static const _log = AppLogger('IngredientSuggestions');

  /// The suggestion ids [markAllNewAsSeen] marked seen. A fetch that
  /// started before the server stored them still has their groups new;
  /// they stay seen.
  final _seenIds = <String>{};

  /// The loads, coalesced per user.
  final _fetches = CoalescedRunner();

  @override
  AsyncValue<List<IngredientSuggestionGroup>> build() {
    _seenIds.clear();
    // A choice („Passt für mich", „Probiere ich", „Passt nicht für mich")
    // ranks the replacements again at once, optimistic writes included.
    // While loading the value may be the previous user's: skipped.
    ref.listen(alternativeChoicesProvider, (_, next) {
      final choices = next.isLoading ? null : next.value;
      if (choices != null) {
        state = state.whenData((g) => rerankGroups(g, choices));
      }
    });
    return const AsyncValue.loading();
  }

  /// [groups] ranked with the choices loaded now; as they come without
  /// choices while those are loading (the value may be the previous
  /// user's; the listener ranks them once loaded) or failed.
  List<IngredientSuggestionGroup> _ranked(
    List<IngredientSuggestionGroup> groups,
  ) {
    final current = ref.read(alternativeChoicesProvider);
    final choices = current.isLoading ? null : current.value;
    return choices == null ? groups : rerankGroups(groups, choices);
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
      if (ref.isCurrentUser(userId)) {
        state = AsyncValue.data(_keepSeen(_ranked(groups)));
      }
    } catch (e, st) {
      _log.error('fetchSuggestions failed', e, st);
      if (ref.isCurrentUser(userId) && !state.hasValue) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Whether [markAllNewAsSeen] marked all of [group]'s suggestions seen
  /// while it still reads new; one with a suggestion added since stays new.
  bool _markedSeen(IngredientSuggestionGroup group) =>
      group.isNew && group.suggestionIds.every(_seenIds.contains);

  /// [groups] with those [markAllNewAsSeen] marked no longer new.
  List<IngredientSuggestionGroup> _keepSeen(
    List<IngredientSuggestionGroup> groups,
  ) => groups.any(_markedSeen)
      ? [for (final g in groups) _markedSeen(g) ? g.copyWith(isNew: false) : g]
      : groups;

  /// Marks the new groups seen: in the list at once (so „n neu" and the
  /// Entdecken dot go as the Alternativen open), then in the backend. If
  /// the backend fails, they are new again.
  Future<void> markAllNewAsSeen() async {
    final groups = state.whenOrNull(data: (g) => g);
    if (groups == null) return;

    final unseenIds = groups
        .where((g) => g.isNew)
        .expand((g) => g.suggestionIds)
        .toList();
    if (unseenIds.isEmpty) return;

    _seenIds.addAll(unseenIds);
    state = AsyncValue.data(_keepSeen(groups));
    try {
      await ref.read(ingredientRepositoryProvider).markAllSeen(unseenIds);
    } catch (e, st) {
      _log.error('markAllNewAsSeen failed', e, st);
      _seenIds.removeAll(unseenIds);
      if (!ref.mounted) return;
      final marked = unseenIds.toSet();
      state = state.whenData(
        (current) => [
          for (final g in current)
            g.suggestionIds.any(marked.contains) ? g.copyWith(isNew: true) : g,
        ],
      );
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
/// loading or failed, and for the groups
/// [IngredientSuggestionNotifier.markAllNewAsSeen] marked seen.
final newIngredientSuggestionCountProvider = Provider<int>((ref) {
  final groups = ref.watch(ingredientSuggestionProvider).value ?? const [];
  return groups.where((g) => g.isNew).length;
});

/// The suggestion groups that contain [mealId], by ingredient name; empty
/// while loading or failed.
final mealSuggestionGroupsProvider = Provider.autoDispose
    .family<List<IngredientSuggestionGroup>, String>((ref, mealId) {
      final groups = ref.watch(ingredientSuggestionProvider).value ?? const [];
      return [
        for (final g in groups)
          if (g.meals.any((m) => m.id == mealId)) g,
      ]..sort(
        (a, b) => a.ingredientName.toLowerCase().compareTo(
          b.ingredientName.toLowerCase(),
        ),
      );
    });
