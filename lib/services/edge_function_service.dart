import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/core_providers.dart';
import '../utils/logger.dart';

class EdgeFunctionService {
  EdgeFunctionService(this._client);

  final SupabaseClient _client;
  static const _log = AppLogger('EdgeFunctionService');

  Future<Map<String, dynamic>> invoke(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _client.functions.invoke(functionName, body: body);
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'data': response.data};
    } catch (e, st) {
      _log.error('invoke($functionName) failed', e, st);
      rethrow;
    }
  }
}

final edgeFunctionServiceProvider = Provider<EdgeFunctionService>(
  (ref) => EdgeFunctionService(ref.watch(supabaseClientProvider)),
);
