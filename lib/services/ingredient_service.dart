import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/core_providers.dart';
import '../utils/logger.dart';

class IngredientSuggestion {
  final String id;
  final String name;
  final bool isOwn;

  const IngredientSuggestion({
    required this.id,
    required this.name,
    required this.isOwn,
  });
}

class IngredientService {
  final SupabaseClient _client;

  IngredientService(this._client);

  static const _log = AppLogger('IngredientService');

  Future<List<IngredientSuggestion>> search(
    String query, {
    int limit = 10,
    required String? userId,
  }) async {
    try {
      final data = await _client
          .from('ingredients')
          .select('id, name, added_by_user_id')
          .ilike('name', '%$query%')
          .limit(limit);
      return data
          .map(
            (e) => IngredientSuggestion(
              id: e['id'] as String,
              name: e['name'] as String,
              isOwn: e['added_by_user_id'] == userId,
            ),
          )
          .toList();
    } catch (e, st) {
      _log.error('search failed', e, st);
      rethrow;
    }
  }

  Future<void> insertIfNew(String name, {required String? userId}) async {
    try {
      if (userId == null) return;
      final existing = await _client
          .from('ingredients')
          .select('id')
          .ilike('name', name)
          .limit(1);
      if (existing.isNotEmpty) return;
      await _client.from('ingredients').insert({
        'name': name,
        'added_via': 'user',
        'added_by_user_id': userId,
      });
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
          .inFilter('suggestion_id', suggestionIds);
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
          .select('id, title, tracked_at, image_url')
          .inFilter('id', mealIds);
    } catch (e, st) {
      _log.error('fetchMealDetails failed', e, st);
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
