import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'ingredient_suggestion_provider.dart';
import 'recommendation_provider.dart';

/// Keeps what Entdecken marks new loaded: the tip sets and the
/// Alternativen. Loads them when a user signs in and, while one is signed
/// in, whenever the app is back in the foreground; pushes and Entdecken
/// call [refresh] themselves. The app root keeps it alive.
class DiscoverNewsNotifier extends Notifier<void> {
  /// The newest load under way for the signed-in user.
  Future<void>? _loading;

  @override
  void build() {
    AppLifecycleListener? lifecycle;
    ref.onDispose(() => lifecycle?.dispose());
    ref.listen<String?>(currentUserIdProvider, (_, userId) {
      lifecycle?.dispose();
      lifecycle = null;
      // Loads for the previous user are not this one's.
      _loading = null;
      if (userId == null) return;
      lifecycle = AppLifecycleListener(onResume: () => unawaited(refresh()));
      // The sign-in load; a load started since covers it.
      Future.microtask(() {
        if (ref.mounted && _loading == null) unawaited(refresh());
      });
    }, fireImmediately: true);
  }

  /// Loads the tip sets and the Alternativen together. Each load is
  /// coalesced: a call while one runs (a push, a resume) makes exactly one
  /// more after it and completes once that one is done. Never throws.
  Future<void> refresh() async {
    if (!ref.mounted) return;
    final load = _loading = Future.wait([
      ref.read(recommendationProvider.notifier).fetchRecommendations(),
      ref.read(ingredientSuggestionProvider.notifier).fetchSuggestions(),
    ]);
    await load;
    if (identical(_loading, load)) _loading = null;
  }
}

final discoverNewsProvider = NotifierProvider<DiscoverNewsNotifier, void>(
  DiscoverNewsNotifier.new,
);

/// Whether Entdecken holds news: an unseen tip set or a new Alternative.
/// The dot on the bar's Entdecken tab.
final discoverBadgeProvider = Provider<bool>(
  (ref) =>
      ref.watch(unseenTipSetProvider) != null ||
      ref.watch(newIngredientSuggestionCountProvider) > 0,
);
