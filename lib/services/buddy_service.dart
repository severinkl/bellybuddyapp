import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/core_providers.dart';

class BuddyService {
  static const _table = 'buddy_state';

  final SupabaseClient _client;
  BuddyService(this._client);

  Future<Map<String, dynamic>?> fetchByUserId(String userId) async {
    return _client.from(_table).select().eq('user_id', userId).maybeSingle();
  }

  Future<void> upsert(Map<String, dynamic> data) async {
    await _client.from(_table).upsert(data, onConflict: 'user_id');
  }
}

final buddyServiceProvider = Provider<BuddyService>(
  (ref) => BuddyService(ref.watch(supabaseClientProvider)),
);
