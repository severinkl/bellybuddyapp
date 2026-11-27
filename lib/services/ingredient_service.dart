import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ingredient_search_result.dart';
import '../providers/core_providers.dart';
import '../utils/logger.dart';
import '../utils/wall_clock.dart';
import 'entry_query_service.dart';

export '../models/ingredient_search_result.dart';

class IngredientService {
  final SupabaseClient _client;

  IngredientService(this._client);

  static const _log = AppLogger('IngredientService');

  /// Ingredients matching [query] by their name or one of their other
  /// names, best matches first ([IngredientSearchResult.rank]): at most
  /// [limit]. `search_ingredients` (core) finds them; each result keeps the
  /// word that matched ([IngredientSearchResult.matchedName]).
  Future<List<IngredientSearchResult>> search(
    String query, {
    int limit = 10,
    required String? userId,
  }) async {
    try {
      final rows = await _client.rpc(
        'search_ingredients',
        // A small margin: the own row wins over a shared one found under the
        // same word, and that may drop rows after the server's limit.
        params: {'p_query': query, 'p_limit': min(limit + 5, 50)},
      );
      return IngredientSearchResult.rank(
        [
          for (final e in (rows as List).cast<Map<String, dynamic>>())
            IngredientSearchResult(
              id: e['id'] as String,
              name: e['name'] as String,
              matchedName: e['matched_name'] as String,
              isOwn: e['added_by_user_id'] == userId,
            ),
        ],
        query: query,
        limit: limit,
      );
    } catch (e, st) {
      _log.error('search failed', e, st);
      rethrow;
    }
  }

  /// Adds [name] to the catalog as the user's own ingredient, unless the
  /// user can read it already (own or shared): `ensure_ingredient` (core
  /// 0011) decides, and never fails on a duplicate. The returned id is not
  /// needed. Errors: 22023 for an empty or too long name; PGRST202 before
  /// the backend has the function.
  Future<void> insertIfNew(String name, {required String? userId}) async {
    if (userId == null) return;
    try {
      await _client.rpc('ensure_ingredient', params: {'p_name': name});
    } catch (e, st) {
      _log.error('insertIfNew failed', e, st);
      rethrow;
    }
  }

  Future<void> deleteUserIngredient(String id) async {
    try {
      await _client.from('ingredients').delete().eq('id', id);
    } catch (e, st) {
      _log.error('deleteUserIngredient failed', e, st);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchSuggestions(String userId) async {
    try {
      return await _client
          .from('ingredient_suggestions')
          .select(
            'id, detected_ingredient_id, helptext, meal_id, seen_at, dismissed_at, '
            'created_at, '
            'ingredients!ingredient_suggestions_detected_ingredient_id_fkey(id, name, image_url)',
          )
          .eq('user_id', userId)
          .isFilter('dismissed_at', null);
    } catch (e, st) {
      _log.error('fetchSuggestions failed', e, st);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchReplacements(
    List<String> suggestionIds,
  ) async {
    if (suggestionIds.isEmpty) return [];
    try {
      return await _client
          .from('ingredient_suggestion_replacements')
          .select('suggestion_id, ingredients(id, name, image_url)')
          .inFilter('suggestion_id', suggestionIds)
          // Rows of one transaction share created_at: id keeps the order stable.
          .order('created_at')
          .order('id');
    } catch (e, st) {
      _log.error('fetchReplacements failed', e, st);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMealDetails(
    List<String> mealIds,
  ) async {
    if (mealIds.isEmpty) return [];
    try {
      return await _client
          .from('meal_entries')
          .select('id, title, tracked_at, image_url, ingredients')
          .inFilter('id', mealIds);
    } catch (e, st) {
      _log.error('fetchMealDetails failed', e, st);
      rethrow;
    }
  }

  /// The user's meals (`id, tracked_at, ingredients`) with `tracked_at`
  /// since [since] (wall clock), page by page ([fetchPagedSince]), for
  /// ranking the alternatives.
  Future<List<Map<String, dynamic>>> fetchMealsSince(
    String userId,
    DateTime since,
  ) async {
    try {
      return await fetchPagedSince(
        _client,
        'meal_entries',
        'id, tracked_at, ingredients',
        userId,
        wallClockToWire(since),
      );
    } catch (e, st) {
      _log.error('fetchMealsSince failed', e, st);
      rethrow;
    }
  }

  Future<void> markAllSeen(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _client
          .from('ingredient_suggestions')
          .update({'seen_at': DateTime.now().toIso8601String()})
          .inFilter('id', ids);
    } catch (e, st) {
      _log.error('markAllSeen failed', e, st);
      rethrow;
    }
  }

  Future<void> dismissSuggestions(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _client
          .from('ingredient_suggestions')
          .update({'dismissed_at': DateTime.now().toIso8601String()})
          .inFilter('id', ids);
    } catch (e, st) {
      _log.error('dismissSuggestions failed', e, st);
      rethrow;
    }
  }

  Future<int> fetchNewCount(String userId) async {
    try {
      final data = await _client
          .from('ingredient_suggestions')
          .select('id')
          .eq('user_id', userId)
          .isFilter('seen_at', null)
          .isFilter('dismissed_at', null);
      return data.length;
    } catch (e, st) {
      _log.error('fetchNewCount failed', e, st);
      rethrow;
    }
  }
}

final ingredientServiceProvider = Provider<IngredientService>(
  (ref) => IngredientService(ref.watch(supabaseClientProvider)),
);
