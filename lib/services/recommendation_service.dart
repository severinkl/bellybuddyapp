import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recommendation.dart';
import '../providers/core_providers.dart';
import '../utils/logger.dart';

class RecommendationService {
  final SupabaseClient _client;

  RecommendationService(this._client);

  static const _log = AppLogger('RecommendationService');

  Future<List<Recommendation>> fetchByUserId(String userId) async {
    try {
      final data = await _client
          .from('recommendations')
          .select()
          .eq('user_id', userId)
          .neq('state', 'hidden')
          .order('created_at', ascending: false);
      return data.map((e) => Recommendation.fromJson(e)).toList();
    } catch (e, st) {
      _log.error('fetchByUserId failed', e, st);
      rethrow;
    }
  }

  /// Stamps the sets [ids] of [userId] seen, those not seen yet; a set
  /// that arrived since they were loaded stays new. Rethrows on failure.
  Future<void> markSeen(String userId, List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _client
          .from('recommendations')
          .update({'seen_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', userId)
          .inFilter('id', ids)
          .isFilter('seen_at', null);
    } catch (e, st) {
      _log.error('markSeen failed', e, st);
      rethrow;
    }
  }

  /// Writes the three feedback columns unconditionally — including explicit
  /// nulls for `dislike_comment` — so transitions like `disliked` → `liked`
  /// clear the comment on the server.
  Future<void> updateFeedback({
    required String id,
    required RecommendationState state,
    String? dislikeComment,
  }) async {
    try {
      await _client
          .from('recommendations')
          .update({
            'state': state.dbValue,
            'dislike_comment': dislikeComment,
            'rated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    } catch (e, st) {
      _log.error('updateFeedback failed for id=$id', e, st);
      rethrow;
    }
  }
}

final recommendationServiceProvider = Provider<RecommendationService>(
  (ref) => RecommendationService(ref.watch(supabaseClientProvider)),
);
