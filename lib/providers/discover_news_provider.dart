import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/logger.dart';
import 'auth_provider.dart';
import 'ingredient_suggestion_provider.dart';
import 'recommendation_provider.dart';

/// Keeps what Entdecken marks new loaded: the tip sets and the
/// Alternativen. Loads them when a user signs in and, while one is signed
/// in, whenever the app is back in the foreground; pushes and Entdecken
/// call [refresh] themselves. The app root keeps it alive.
class DiscoverNewsNotifier extends Notifier<void> {
  static const _log = AppLogger('DiscoverNews');

  /// The loads under way, for the signed-in user.
  _Run? _run;

  @override
  void build() {
    AppLifecycleListener? lifecycle;
    ref.onDispose(() => lifecycle?.dispose());
    ref.listen<String?>(currentUserIdProvider, (_, userId) {
      lifecycle?.dispose();
      lifecycle = null;
      // Loads for the previous user are not this one's.
      _run = null;
      if (userId == null) return;
      lifecycle = AppLifecycleListener(onResume: () => unawaited(refresh()));
      // The sign-in load; a load started since covers it.
      Future.microtask(() {
        if (ref.mounted && _run == null) unawaited(_start());
      });
    }, fireImmediately: true);
  }

  /// Loads the tip sets and the Alternativen together. A call while a load
  /// runs (a push, a resume) may bring news that load predates: exactly one
  /// more runs after it, however many calls came, and every such call
  /// completes once that one is done. Never throws.
  Future<void> refresh() {
    if (!ref.mounted) return Future.value();
    final run = _run;
    if (run == null) return _start();
    run.again = true;
    return run.done;
  }

  Future<void> _start() {
    final run = _run = _Run();
    return run.done = _loadWhileAsked(run);
  }

  Future<void> _loadWhileAsked(_Run run) async {
    do {
      run.again = false;
      await _load();
    } while (run.again && identical(_run, run) && ref.mounted);
    if (identical(_run, run)) _run = null;
  }

  Future<void> _load() async {
    try {
      await Future.wait([
        ref.read(recommendationProvider.notifier).fetchRecommendations(),
        ref.read(ingredientSuggestionProvider.notifier).fetchSuggestions(),
      ]);
    } catch (e, st) {
      _log.error('refresh failed', e, st);
    }
  }
}

/// A load of [DiscoverNewsNotifier] and the one more asked for while it ran.
class _Run {
  /// Whether [DiscoverNewsNotifier.refresh] was called during the load.
  bool again = false;

  /// Completes once no more load is asked for.
  late final Future<void> done;
}

final discoverNewsProvider = NotifierProvider<DiscoverNewsNotifier, void>(
  DiscoverNewsNotifier.new,
);
