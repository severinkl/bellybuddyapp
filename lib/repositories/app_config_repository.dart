import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_config.dart';
import '../providers/core_providers.dart';

/// Reads the version thresholds and the paywall switch from the `app_config`
/// table.
class AppConfigRepository {
  AppConfigRepository(this._client);

  final SupabaseClient _client;

  /// Throws [StateError] if either `minimum_supported_version` or
  /// `latest_version` is missing. A missing `paywall_enabled` means off.
  Future<AppConfig> fetch() async {
    final rows = await _client
        .from('app_config')
        .select('key, value')
        .inFilter('key', [
          'minimum_supported_version',
          'latest_version',
          'paywall_enabled',
          'akuthilfe_enabled',
        ]);

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
    return AppConfig(
      minimum: minimum,
      latest: latest,
      paywallEnabled: byKey['paywall_enabled'] == 'true',
      akuthilfeEnabled: byKey['akuthilfe_enabled'] == 'true',
    );
  }
}

final appConfigRepositoryProvider = Provider<AppConfigRepository>(
  (ref) => AppConfigRepository(ref.watch(supabaseClientProvider)),
);
