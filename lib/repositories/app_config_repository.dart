import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_config.dart';
import '../providers/core_providers.dart';

/// Reads the version thresholds from the Supabase `app_config` table.
class AppConfigRepository {
  AppConfigRepository(this._client);

  final SupabaseClient _client;

  /// Throws [StateError] if either `minimum_supported_version` or
  /// `latest_version` is missing.
  Future<AppConfig> fetch() async {
    final rows = await _client.from('app_config').select('key, value').inFilter(
      'key',
      ['minimum_supported_version', 'latest_version'],
    );

    final byKey = <String, String>{
      for (final row in rows as List)
        row['key'] as String: row['value'] as String,
    };
    final minimum = byKey['minimum_supported_version'];
    final latest = byKey['latest_version'];
    if (minimum == null || latest == null) {
      throw StateError(
        'app_config missing required keys: '
        'got ${byKey.keys.toList()}',
      );
    }
    return AppConfig(minimum: minimum, latest: latest);
  }
}

final appConfigRepositoryProvider = Provider<AppConfigRepository>(
  (ref) => AppConfigRepository(ref.watch(supabaseClientProvider)),
);
