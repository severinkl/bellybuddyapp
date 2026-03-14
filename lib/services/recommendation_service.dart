import '../models/recommendation.dart';
import 'supabase_service.dart';

class RecommendationService {
  static Future<List<Recommendation>> fetchByUserId(String userId) async {
    final data = await SupabaseService.client
        .from('recommendations')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return data.map((e) => Recommendation.fromJson(e)).toList();
  }
}
