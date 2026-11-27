import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alternative_choice.dart';
import '../models/replacement_ingredient.dart';
import '../services/alternative_choice_service.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';

class AlternativeChoicesNotifier
    extends AsyncNotifier<List<AlternativeChoice>> {
  static const _log = AppLogger('AlternativeChoices');

  int _localIds = 0;

  @override
  Future<List<AlternativeChoice>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    final rows = await ref.read(alternativeChoiceServiceProvider).fetch(userId);
    return [for (final r in rows) AlternativeChoice.fromRow(r)];
  }

  bool _samePair(
    AlternativeChoice c,
    String ingredientId,
    String replacementId,
  ) => c.ingredientId == ingredientId && c.replacementId == replacementId;

  /// Stores [kind] for [replacement] on [ingredientId]: in the list at once,
  /// then replaced by the stored row. A choice already there for the pair is
  /// replaced, not doubled. On failure the list is as before; false.
  Future<bool> choose({
    required String ingredientId,
    required String ingredientName,
    required ReplacementIngredient replacement,
    required AlternativeChoiceKind kind,
  }) async {
    final userId = ref.read(currentUserIdProvider);
    final before = state.value;
    if (userId == null || before == null) return false;

    final existing = before.indexWhere(
      (c) => _samePair(c, ingredientId, replacement.id),
    );
    // A stored row keeps its created_at when the choice changes.
    final provisional = AlternativeChoice(
      id: 'local-${_localIds++}',
      ingredientId: ingredientId,
      ingredientName: ingredientName,
      replacementId: replacement.id,
      replacementName: replacement.name,
      kind: kind,
      createdAt: existing < 0
          ? DateTime.now().toUtc()
          : before[existing].createdAt,
    );
    state = AsyncData(
      existing < 0
          ? [provisional, ...before]
          : [
              for (final (i, c) in before.indexed)
                i == existing ? provisional : c,
            ],
    );

    try {
      final row = await ref
          .read(alternativeChoiceServiceProvider)
          .upsert(
            userId: userId,
            ingredientId: ingredientId,
            replacementId: replacement.id,
            kind: kind,
          );
      if (!ref.isCurrentUser(userId)) return false;
      final stored = AlternativeChoice.fromRow(row);
      state = AsyncData([
        for (final c in state.value ?? const <AlternativeChoice>[])
          _samePair(c, ingredientId, replacement.id) ? stored : c,
      ]);
      return true;
    } catch (e, st) {
      _log.error('choose failed', e, st);
      if (ref.isCurrentUser(userId)) {
        final current = state.value ?? const <AlternativeChoice>[];
        final rest = [
          for (final c in current)
            if (!_samePair(c, ingredientId, replacement.id)) c,
        ];
        state = AsyncData(
          existing < 0
              ? rest
              : [
                  ...rest.take(existing),
                  before[existing],
                  ...rest.skip(existing),
                ],
        );
      }
      return false;
    }
  }

  /// Deletes the choice: out of the list at once; on failure it is back; false.
  Future<bool> remove(String choiceId) async {
    final userId = ref.read(currentUserIdProvider);
    final before = state.value;
    if (before == null) return false;
    final index = before.indexWhere((c) => c.id == choiceId);
    if (index < 0) return false;
    final removed = before[index];

    state = AsyncData([
      for (final c in before)
        if (c.id != choiceId) c,
    ]);
    try {
      await ref.read(alternativeChoiceServiceProvider).delete(choiceId);
      return true;
    } catch (e, st) {
      _log.error('remove failed', e, st);
      if (ref.isCurrentUser(userId)) {
        final rest = state.value ?? const <AlternativeChoice>[];
        final at = index.clamp(0, rest.length);
        state = AsyncData([...rest.take(at), removed, ...rest.skip(at)]);
      }
      return false;
    }
  }
}

final alternativeChoicesProvider =
    AsyncNotifierProvider<AlternativeChoicesNotifier, List<AlternativeChoice>>(
      AlternativeChoicesNotifier.new,
    );

/// (ingredientId, replacementId) of every choice, try or skip; empty while
/// loading or failed.
final chosenAlternativesProvider = Provider<Set<(String, String)>>((ref) {
  final choices = ref.watch(alternativeChoicesProvider).value ?? const [];
  return {for (final c in choices) (c.ingredientId, c.replacementId)};
});

/// The „Probiere ich" rows, newest first.
final triedAlternativesProvider = Provider<List<AlternativeChoice>>((ref) {
  final choices = ref.watch(alternativeChoicesProvider).value ?? const [];
  return [
    for (final c in choices)
      if (c.kind == AlternativeChoiceKind.tryIt) c,
  ];
});
