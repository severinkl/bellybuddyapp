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
          .order('created_at', ascending: false);
      return data.map((e) => Recommendation.fromJson(e)).toList();
    } catch (e, st) {
      _log.error('fetchByUserId failed', e, st);
      rethrow;
    }
  }

  Future<int> countUnseen(String userId) async {
    try {
      final result = await _client
          .from('recommendations')
          .select()
          .eq('user_id', userId)
          .isFilter('seen_at', null)
          .count(CountOption.exact);
      return result.count;
    } catch (e, st) {
      _log.error('countUnseen failed', e, st);
      return 0;
    }
  }

  Future<void> markAllAsSeen(String userId) async {
    try {
      await _client
          .from('recommendations')
          .update({'seen_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', userId)
          .isFilter('seen_at', null);
    } catch (e, st) {
      _log.error('markAllAsSeen failed', e, st);
    }
  }
}

final recommendationServiceProvider = Provider<RecommendationService>(
  (ref) => RecommendationService(ref.watch(supabaseClientProvider)),
);
