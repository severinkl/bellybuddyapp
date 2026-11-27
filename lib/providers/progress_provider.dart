import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/progress.dart';
import '../repositories/entry_repository.dart';
import '../services/progress/progress_engine.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';
import 'buddy_provider.dart';
import 'entry_window_notifier.dart';

/// The signed-in user's „Dein Verlauf" ([Progress], the last
/// [ProgressRules.weeks] Monday weeks) as of the app's clock
/// ([buddyClockProvider]); null while signed out. The Buddy's saved days
/// count for the longest streak (none without a Buddy or when it fails).
///
/// Computed again after every entry write, on a new day, when the Buddy's
/// saved days change (e.g. its new-day sync spends a saver) and on
/// [refresh];
/// see [EntryWindowNotifier]. How a screen reads the state:
/// 1. [AsyncValue.hasError]: the error state.
/// 2. [AsyncValue.isReloading] (a user change): loading.
/// 3. Otherwise the value, which stays while a refetch loads.
/// (`currentValue` in `utils/settled_value.dart` is steps 1-3 as a null.)
class ProgressNotifier extends EntryWindowNotifier<Progress?> {
  static const _log = AppLogger('Progress');

  @override
  AppLogger get log => _log;

  @override
  String get subject => 'progress';

  /// The saved days the last computation used; null before one read them.
  Set<DateTime>? _usedSavedDays;

  @override
  void listenForRefetch(void Function() refetch) {
    _usedSavedDays = null;
    ref.listen(buddyProvider.select((b) => b.value?.state.savedDays), (
      _,
      next,
    ) {
      final used = _usedSavedDays;
      // No value (loading, failed, no Buddy), or the running first
      // computation still reads them: nothing to catch up.
      if (next == null || used == null) return;
      if (next.length == used.length && used.containsAll(next)) return;
      // Inside the Buddy's state change its future may still be the old
      // one: read it after the change.
      final opRef = ref;
      scheduleMicrotask(() {
        if (opRef.mounted) refetch();
      });
    });
  }

  @override
  Future<Progress?> compute(String? userId) async {
    if (userId == null) return null;
    final now = ref.read(buddyClockProvider)();
    final savedDays = _savedDays();
    final source = await ref
        .read(entryRepositoryProvider)
        .fetchProgressSource(userId: userId, now: now);
    return computeProgress(source, now: now, savedDays: await savedDays);
  }

  /// The Buddy's saved days; none without a Buddy or when it fails (its
  /// provider logs that).
  Future<Set<DateTime>> _savedDays() async {
    try {
      final buddy = await ref.read(buddyProvider.future);
      return _usedSavedDays = {...?buddy?.state.savedDays};
    } catch (_) {
      return _usedSavedDays = const {};
    }
  }
}

/// „Dein Verlauf" and the recent signals „Für dich" reads. No automatic
/// rebuild retries: a failed load stays an error until the next entry
/// write, new day or refresh.
final progressProvider = AsyncNotifierProvider<ProgressNotifier, Progress?>(
  ProgressNotifier.new,
  retry: noRetry,
);
