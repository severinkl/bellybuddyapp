import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recommendation.dart';
import '../providers/core_providers.dart';
import '../utils/date_format_utils.dart';
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

  /// Fetches recent meals and toilet entries (last 7 days) for AI context.
  Future<Map<String, dynamic>> fetchRecentContext(String userId) async {
    try {
      final sevenDaysAgo = last7Days().toIso8601String();

      final mealsFuture = _client
          .from('meal_entries')
          .select('title, ingredients')
          .eq('user_id', userId)
          .gte('created_at', sevenDaysAgo)
          .order('created_at', ascending: false)
          .limit(20);

      final toiletFuture = _client
          .from('toilet_entries')
          .select('stool_type')
          .eq('user_id', userId)
          .gte('created_at', sevenDaysAgo)
          .order('created_at', ascending: false)
          .limit(10);

      final results = await Future.wait([mealsFuture, toiletFuture]);

      return {'recentMeals': results[0], 'recentToilet': results[1]};
    } catch (e, st) {
      _log.error('fetchRecentContext failed', e, st);
      rethrow;
    }
  }
}

final recommendationServiceProvider = Provider<RecommendationService>(
  (ref) => RecommendationService(ref.watch(supabaseClientProvider)),
);
