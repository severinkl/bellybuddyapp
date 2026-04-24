import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_recipe.dart';
import '../utils/logger.dart';

class UserRecipeService {
  UserRecipeService(this._client);

  final SupabaseClient _client;
  static const _log = AppLogger('UserRecipeService');
  static const _table = 'user_recipes';

  Future<List<UserRecipe>> fetchForUser(String userId) async {
    try {
      final data = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => UserRecipe.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _log.error('fetchForUser failed', e, st);
      rethrow;
    }
  }

  Future<UserRecipe> create({
    required String userId,
    required String title,
    required List<String> ingredients,
    String? imageUrl,
  }) async {
    try {
      final data = await _client
          .from(_table)
          .insert({
            'user_id': userId,
            'title': title,
            'ingredients': ingredients,
            'image_url': imageUrl,
          })
          .select()
          .single();
      return UserRecipe.fromJson(data);
    } catch (e, st) {
      _log.error('create failed', e, st);
      rethrow;
    }
  }

  Future<UserRecipe> update({
    required String id,
    required String title,
    required List<String> ingredients,
    String? imageUrl,
  }) async {
    try {
      final data = await _client
          .from(_table)
          .update({
            'title': title,
            'ingredients': ingredients,
            'image_url': imageUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();
      return UserRecipe.fromJson(data);
    } catch (e, st) {
      _log.error('update failed', e, st);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from(_table).delete().eq('id', id);
    } catch (e, st) {
      _log.error('delete failed', e, st);
      rethrow;
    }
  }
}
