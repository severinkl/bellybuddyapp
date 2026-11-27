import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dietitian_tip.dart';
import '../services/dietitian_tip_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';
import 'app_foreground_provider.dart';
import 'auth_provider.dart';
import 'user_scoped_refresh.dart';

/// The tips from the user's dietitians, newest first. Empty while nobody
/// is signed in. Loads again when the app is back in the foreground
/// ([appForegroundProvider]) and on a push about a tip
/// (`DiscoverNewsNotifier.pushArrived`), since a kept-alive Entdecken does
/// not load by itself. Logs ids at most, never a tip's text.
class DietitianTipsNotifier extends AsyncNotifier<List<DietitianTip>>
    with UserScopedRefresh<List<DietitianTip>> {
  static const _log = AppLogger('DietitianTipsProvider');

  /// The tips already stamped seen, so a rebuild of the section does not
  /// send the same write again.
  final Set<String> _stamped = {};

  @override
  Future<List<DietitianTip>> build() async {
    ref.listen(appForegroundProvider, (_, _) => unawaited(refresh()));
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    return ref.read(dietitianTipServiceProvider).list();
  }

  /// Loads the tips again, keeping what is shown while it runs.
  Future<void> refresh() =>
      refreshWith((_) => ref.read(dietitianTipServiceProvider).list(), _log);

  /// Stamps every tip not seen yet as seen (`seen_at`), once each. The
  /// state keeps them new, so the „Neu" badge stays until the next load.
  /// A failure is logged and tried again on the next call.
  Future<void> markShownSeen() async {
    final ids = [
      for (final tip in state.value ?? const <DietitianTip>[])
        if (tip.isNew && !_stamped.contains(tip.id)) tip.id,
    ];
    if (ids.isEmpty) return;
    _stamped.addAll(ids);
    try {
      await ref.read(dietitianTipServiceProvider).markSeen(ids);
    } catch (e, st) {
      _stamped.removeAll(ids);
      _log.error('marking the tips seen failed', e, st);
    }
  }

  /// „Probiere ich" on or off for tip [id]. A failing call throws and
  /// leaves the state as it was.
  Future<void> toggleTrying(String id) async {
    final tips = state.value ?? const <DietitianTip>[];
    final tip = tips.where((t) => t.id == id).firstOrNull;
    if (tip == null) return;
    final trying = tip.tryingAt == null;
    await ref.read(dietitianTipServiceProvider).setTrying(id, trying);
    if (!ref.mounted) return;
    state = AsyncData([
      for (final t in state.value ?? tips)
        t.id == id ? t.copyWith(tryingAt: trying ? DateTime.now() : null) : t,
    ]);
  }

  /// Deletes tip [id]. A failing call throws and leaves the state as it was.
  Future<void> remove(String id) async {
    await ref.read(dietitianTipServiceProvider).remove(id);
    if (!ref.mounted) return;
    state = AsyncData([
      for (final t in state.value ?? const <DietitianTip>[])
        if (t.id != id) t,
    ]);
  }
}

/// No automatic rebuild retries; the section stays away while it fails.
final dietitianTipsProvider =
    AsyncNotifierProvider<DietitianTipsNotifier, List<DietitianTip>>(
      DietitianTipsNotifier.new,
      retry: noRetry,
    );
