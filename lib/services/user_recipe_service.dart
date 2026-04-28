import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_recipe.dart';
import '../utils/logger.dart';

/// Thrown when the DB rejects an insert/update because another recipe by
/// the same user already has the same (case- and whitespace-normalised)
/// title. Maps to Postgres error code `23505` from the
/// `user_recipes_user_id_title_norm_uniq` index.
class DuplicateRecipeTitleException implements Exception {
  const DuplicateRecipeTitleException();
}

const _pgUniqueViolation = '23505';

class UserRecipeService {
  UserRecipeService(this._client);

  final SupabaseClient _client;
  static const _log = AppLogger('UserRecipeService');
  static const _table = 'user_recipes';

  Future<List<UserRecipe>> searchForUser(String userId, String query) async {
    final tsQuery = buildTsQuery(query);
    if (tsQuery.isEmpty) return fetchForUser(userId);
    try {
      final data = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .textSearch('search_tsv', tsQuery, config: 'german')
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => UserRecipe.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _log.error('searchForUser failed', e, st);
      rethrow;
    }
  }

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
    } on PostgrestException catch (e, st) {
      if (e.code == _pgUniqueViolation) {
        throw const DuplicateRecipeTitleException();
      }
      _log.error('create failed', e, st);
      rethrow;
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
    } on PostgrestException catch (e, st) {
      if (e.code == _pgUniqueViolation) {
        throw const DuplicateRecipeTitleException();
      }
      _log.error('update failed', e, st);
      rethrow;
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

  static final _whitespaceRx = RegExp(r'\s+');
  // tsquery's reserved characters — `&`, `|`, `!`, `(`, `)`, `:`, `*`,
  // `<`, `>` — would otherwise produce a malformed query and surface as
  // a 400 from PostgREST. Strip everything that isn't a Unicode letter,
  // digit, or underscore. `\w` is ASCII-only in Dart's RegExp even with
  // `unicode: true`, which would drop umlauts (Möhren → Mhren).
  static final _tsqueryStripRx = RegExp(r'[^\p{L}\p{N}_]', unicode: true);

  /// Converts a free-form user query into a tsquery string with prefix-match
  /// per token (`token:*`) joined by `&` so multi-word queries narrow.
  /// Exposed for tests; not part of the public API.
  static String buildTsQuery(String query) {
    final tokens = query
        .trim()
        .split(_whitespaceRx)
        .map((t) => t.replaceAll(_tsqueryStripRx, ''))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return '';
    return tokens.map((t) => '$t:*').join(' & ');
  }
}
