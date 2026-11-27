import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/alternative_choice.dart';
import '../providers/core_providers.dart';
import '../utils/logger.dart';

class AlternativeChoiceService {
  final SupabaseClient _client;

  AlternativeChoiceService(this._client);

  static const _log = AppLogger('AlternativeChoiceService');

  static const _columns =
      'id, ingredient_id, replacement_ingredient_id, choice, created_at, '
      'ingredient:ingredients!alternative_choices_ingredient_id_fkey(name), '
      'replacement:ingredients!alternative_choices_replacement_ingredient_id_fkey(name)';

  /// The user's choices, newest first.
  Future<List<Map<String, dynamic>>> fetch(String userId) async {
    try {
      return await _client
          .from('alternative_choices')
          .select(_columns)
          .eq('user_id', userId)
          .order('created_at', ascending: false);
    } catch (e, st) {
      _log.error('fetch failed', e, st);
      rethrow;
    }
  }

  /// Stores the choice; a second one for the same pair replaces the first.
  Future<Map<String, dynamic>> upsert({
    required String userId,
    required String ingredientId,
    required String replacementId,
    required AlternativeChoiceKind kind,
  }) async {
    try {
      return await _client
          .from('alternative_choices')
          .upsert({
            'user_id': userId,
            'ingredient_id': ingredientId,
            'replacement_ingredient_id': replacementId,
            'choice': kind.db,
          }, onConflict: 'user_id,ingredient_id,replacement_ingredient_id')
          .select(_columns)
          .single();
    } catch (e, st) {
      _log.error('upsert failed', e, st);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from('alternative_choices').delete().eq('id', id);
    } catch (e, st) {
      _log.error('delete failed', e, st);
      rethrow;
    }
  }
}

final alternativeChoiceServiceProvider = Provider<AlternativeChoiceService>(
  (ref) => AlternativeChoiceService(ref.watch(supabaseClientProvider)),
);
