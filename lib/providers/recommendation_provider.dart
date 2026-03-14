import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recommendation.dart';
import '../services/supabase_service.dart';
import '../services/edge_function_service.dart';

class RecommendationNotifier extends Notifier<AsyncValue<List<Recommendation>>> {
  @override
  AsyncValue<List<Recommendation>> build() => const AsyncValue.loading();

  Future<void> fetchRecommendations() async {
    state = const AsyncValue.loading();
    try {
      final userId = SupabaseService.userId;
      if (userId == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final data = await SupabaseService.client
          .from('recommendations')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      state = AsyncValue.data(
        data.map((e) => Recommendation.fromJson(e)).toList(),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refreshRecommendations() async {
    try {
      await EdgeFunctionService.invoke('diet-recommendations');
      await fetchRecommendations();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final recommendationProvider =
    NotifierProvider<RecommendationNotifier, AsyncValue<List<Recommendation>>>(
        RecommendationNotifier.new);
