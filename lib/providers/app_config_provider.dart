import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_config.dart';
import '../repositories/app_config_repository.dart';

/// Version thresholds from the `app_config` table. Callers (the splash in
/// particular) treat a failure as "fail open" — log and proceed as if the
/// version is fine.
final appConfigProvider = FutureProvider<AppConfig>(
  (ref) => ref.watch(appConfigRepositoryProvider).fetch(),
);
