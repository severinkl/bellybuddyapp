import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/logger.dart';
import 'auth_provider.dart';
import 'ingredient_suggestion_provider.dart';
import 'recommendation_provider.dart';

/// Keeps what Entdecken marks new loaded: the tip sets and the
/// Alternativen. Refreshes when a user signs in and, while one is signed
/// in, whenever the app is back in the foreground; pushes and Entdecken
/// call [refresh] themselves. The app root keeps it alive.
class DiscoverNewsNotifier extends Notifier<void> {
  static const _log = AppLogger('DiscoverNews');

  /// The refresh under way; later calls join it.
  Future<void>? _running;

  @override
  void build() {
    AppLifecycleListener? lifecycle;
    ref.onDispose(() => lifecycle?.dispose());
    ref.listen<String?>(currentUserIdProvider, (_, userId) {
      lifecycle?.dispose();
      lifecycle = null;
      // A refresh for the previous user is not this one's to join.
      _running = null;
      if (userId == null) return;
      lifecycle = AppLifecycleListener(onResume: () => unawaited(refresh()));
      Future.microtask(() {
        if (ref.mounted) unawaited(refresh());
      });
    }, fireImmediately: true);
  }

  /// Loads the tip sets and the Alternativen together, or joins the load
  /// already under way. Never throws.
  Future<void> refresh() {
    if (!ref.mounted) return Future.value();
    final running = _running;
    if (running != null) return running;
    final load = _load();
    _running = load;
    return load.whenComplete(() {
      if (identical(_running, load)) _running = null;
    });
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

final discoverNewsProvider = NotifierProvider<DiscoverNewsNotifier, void>(
  DiscoverNewsNotifier.new,
);
