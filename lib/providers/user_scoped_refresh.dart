import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/logger.dart';
import 'auth_provider.dart';

/// A refresh for an [AsyncNotifier] whose data belongs to the signed-in
/// user.
mixin UserScopedRefresh<T> on AsyncNotifier<T> {
  /// Fetches with [fetch] for the signed-in user and shows the result while
  /// they are still signed in (a previous user's late result lands nowhere).
  /// Without data on show it is loading meanwhile, so a retry shows it is
  /// working. A failure is logged to [log] and keeps the data on show;
  /// without, it is the error again. Signed out: nothing.
  ///
  /// An error is never data on show, even when it still carries the value
  /// from before a failed rebuild (e.g. the signed-out empty list after an
  /// offline sign-in).
  ///
  /// A result [outdated] says is older than the data on show is dropped.
  Future<void> refreshWith(
    Future<T> Function(String userId) fetch,
    AppLogger log, {
    bool Function()? outdated,
  }) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    if (!_showsData) state = AsyncLoading<T>();
    try {
      final value = await fetch(userId);
      if (!ref.isCurrentUser(userId)) return;
      if (_showsData && (outdated?.call() ?? false)) return;
      state = AsyncData(value);
    } catch (e, st) {
      log.error('refresh failed', e, st);
      if (ref.isCurrentUser(userId) && !_showsData) {
        state = AsyncError(e, st);
      }
    }
  }

  bool get _showsData => state.hasValue && !state.hasError;
}
