import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dietitian_tip.dart';
import '../providers/core_providers.dart';
import '../utils/logger.dart';

/// The client's tips from their dietitians (`dietitian_recommendations`).
/// RLS limits every call to the user's own rows; the client may only set
/// `seen_at` / `trying_at` and delete. Logs ids at most, never a body.
class DietitianTipService {
  DietitianTipService(this._client);

  final SupabaseClient _client;

  static const _log = AppLogger('DietitianTipService');
  static const _table = 'dietitian_recommendations';

  static const columns =
      'id, sender_name, sender_profession, body, created_at, seen_at, '
      'trying_at';

  static String _now() => DateTime.now().toUtc().toIso8601String();

  Future<List<DietitianTip>> list() async {
    try {
      final rows = await _client
          .from(_table)
          .select(columns)
          .order('created_at', ascending: false);
      return rows.map(DietitianTip.fromJson).toList();
    } catch (e, st) {
      _log.error('list failed', e, st);
      rethrow;
    }
  }

  /// Stamps the tips [ids] seen, those not seen yet; a tip that arrived
  /// since they were loaded stays new.
  Future<void> markSeen(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _client
          .from(_table)
          .update({'seen_at': _now()})
          .inFilter('id', ids)
          .isFilter('seen_at', null);
    } catch (e, st) {
      _log.error('markSeen failed', e, st);
      rethrow;
    }
  }

  /// „Probiere ich" on (now) or off (null).
  Future<void> setTrying(String id, bool trying) async {
    try {
      await _client
          .from(_table)
          .update({'trying_at': trying ? _now() : null})
          .eq('id', id);
    } catch (e, st) {
      _log.error('setTrying failed for id=$id', e, st);
      rethrow;
    }
  }

  Future<void> remove(String id) async {
    try {
      await _client.from(_table).delete().eq('id', id);
    } catch (e, st) {
      _log.error('remove failed for id=$id', e, st);
      rethrow;
    }
  }
}

final dietitianTipServiceProvider = Provider<DietitianTipService>(
  (ref) => DietitianTipService(ref.watch(supabaseClientProvider)),
);
