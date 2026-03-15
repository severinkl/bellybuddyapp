import '../utils/logger.dart';

/// Retries an async operation with exponential backoff.
///
/// Calls [fn] up to [maxAttempts] times. On failure, waits
/// `backoff * attempt` before retrying. Rethrows the last error
/// if all attempts fail.
Future<T> retryAsync<T>(
  Future<T> Function() fn, {
  int maxAttempts = 3,
  Duration backoff = const Duration(seconds: 2),
  AppLogger? log,
  String? label,
}) async {
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (e) {
      log?.error('${label ?? 'retryAsync'} (attempt $attempt/$maxAttempts)', e);
      if (attempt >= maxAttempts) rethrow;
      await Future.delayed(backoff * attempt);
    }
  }
  // Unreachable, but required by the type system
  throw StateError('retryAsync: unreachable');
}
