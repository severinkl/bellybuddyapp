import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/first_tip.dart';
import '../models/meal_entry.dart';
import '../models/recommendation.dart';
import '../providers/core_providers.dart';
import '../utils/logger.dart';
import '../utils/wall_clock.dart';

class RecommendationService {
  final SupabaseClient _client;

  RecommendationService(this._client);

  static const _log = AppLogger('RecommendationService');

  /// Core's function behind the day-3 first tip.
  static const firstTipFunction = 'diet-recommendations';

  /// Asks core for the day-3 first tip ([firstTipFunction]); core saves the
  /// set it makes. The body is exactly the profile's [intolerances] and
  /// [diet] and the [meals]' title, ingredients and wall-clock `tracked_at`.
  /// Only the answer's `id` and its number of tips are read.
  ///
  /// Every failure is a [FirstTipException]: an error answer with its
  /// status; no connection, or an answer that can't be read, without one.
  /// Logs name the status only, never a meal.
  Future<FirstTipResult> requestFirstTip({
    required List<String> intolerances,
    required String? diet,
    required List<MealEntry> meals,
  }) async {
    final Object? data;
    try {
      final response = await _client.functions.invoke(
        firstTipFunction,
        body: {
          'intolerances': intolerances,
          'diet': diet,
          'recentMeals': [
            for (final meal in meals)
              {
                'title': meal.title,
                'ingredients': meal.ingredients,
                'tracked_at': wallClockToWire(meal.trackedAt),
              },
          ],
        },
      );
      data = response.data;
    } on FunctionsFetchException {
      // The request never got an answer (status 0): no status to name.
      _log.error('requestFirstTip failed: no answer');
      throw const FirstTipException();
    } on FunctionException catch (e) {
      _log.error('requestFirstTip failed (${e.status})');
      throw FirstTipException(e.status);
    } catch (e) {
      _log.error('requestFirstTip failed (${e.runtimeType})');
      throw const FirstTipException();
    }
    try {
      if (data is! Map) throw const FormatException('not a JSON object');
      return FirstTipResult(
        id: data['id'] as String?,
        tips: (data['recommendations'] as List?)?.length ?? 0,
      );
    } catch (e) {
      // The answer itself is never logged: it may repeat the meals.
      _log.error('requestFirstTip: unreadable answer (${e.runtimeType})');
      throw const FirstTipException();
    }
  }

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
