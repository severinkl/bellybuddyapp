import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/logger.dart';
import 'auth_provider.dart';

/// A refresh for an [AsyncNotifier] whose data belongs to the signed-in
/// user.
mixin UserScopedRefresh<T> on AsyncNotifier<T> {
  /// Fetches with [fetch] for the signed-in user and shows the result while
  /// they are still signed in (a previous user's late result lands nowhere).
  /// A failure is logged to [log] and keeps the data on show; without data,
  /// the error stays. Signed out: nothing.
  Future<void> refreshWith(
    Future<T> Function(String userId) fetch,
    AppLogger log,
  ) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      final value = await fetch(userId);
      if (ref.isCurrentUser(userId)) state = AsyncData(value);
    } catch (e, st) {
      log.error('refresh failed', e, st);
      if (ref.isCurrentUser(userId) && !state.hasValue) {
        state = AsyncError(e, st);
      }
    }
  }
}
