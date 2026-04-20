import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_config.dart';
import 'core_providers.dart';

/// Fetches version thresholds from the Supabase `app_config` table.
///
/// Throws [StateError] if either `minimum_supported_version` or
/// `latest_version` is missing. Callers (the splash in particular) treat a
/// failure as "fail open" — log and proceed as if the version is fine.
final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final rows = await client.from('app_config').select('key, value').inFilter(
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
});
