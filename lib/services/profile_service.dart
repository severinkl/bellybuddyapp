import '../models/user_profile.dart';
import '../utils/logger.dart';
import 'supabase_service.dart';

class ProfileService {
  static const _log = AppLogger('ProfileService');
  static const _table = 'profiles';

  static Future<UserProfile?> fetchByUserId(String userId) async {
    _log.debug('fetchByUserId: userId=$userId');
    final data = await SupabaseService.client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    _log.debug('fetchByUserId: data=$data');
    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  static Future<void> upsert(Map<String, dynamic> data) async {
    await SupabaseService.client
        .from(_table)
        .upsert(data, onConflict: 'user_id');
  }

  static Future<void> update(String userId, Map<String, dynamic> data) async {
    await SupabaseService.client
        .from(_table)
        .update(data)
        .eq('user_id', userId);
  }
}
