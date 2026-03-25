import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../providers/core_providers.dart';
import '../utils/logger.dart';

class ProfileService {
  static const _log = AppLogger('ProfileService');
  static const _table = 'profiles';

  final SupabaseClient _client;
  ProfileService(this._client);

  Future<UserProfile?> fetchByUserId(String userId) async {
    _log.debug('fetchByUserId: userId=$userId');
    final data = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    _log.debug('fetchByUserId: data=$data');
    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  Future<void> upsert(Map<String, dynamic> data) async {
    await _client.from(_table).upsert(data, onConflict: 'user_id');
  }

  Future<void> update(String userId, Map<String, dynamic> data) async {
    await _client.from(_table).update(data).eq('user_id', userId);
  }
}

final profileServiceProvider = Provider<ProfileService>(
  (ref) => ProfileService(ref.watch(supabaseClientProvider)),
);
