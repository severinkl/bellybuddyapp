import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../router/route_names.dart';
import 'app_foreground_provider.dart';
import 'auth_provider.dart';
import 'buddy_provider.dart';
import 'dietitian_tips_provider.dart';
import 'ingredient_suggestion_provider.dart';
import 'recommendation_provider.dart';

/// Keeps what Entdecken marks new loaded: the tip sets and the
/// Alternativen. Loads them when a user signs in and, while one is signed
/// in, when the app is back in the foreground ([appForegroundProvider]) and
/// the last load is [AppConstants.discoverNewsForegroundInterval] old;
/// pushes about them ([pushArrived]) and pull to refresh load them too,
/// Entdecken's first load joins ([ensureLoaded]). The app root keeps it alive.
class DiscoverNewsNotifier extends Notifier<void> {
  /// The newest load under way for the signed-in user.
  Future<void>? _loading;

  /// When the last load for the signed-in user finished.
  DateTime? _loadedAt;

  DateTime _now() => ref.read(buddyClockProvider)();

  @override
  void build() {
    ref.listen(appForegroundProvider, (_, _) => _onForeground());
    ref.listen<String?>(currentUserIdProvider, (_, userId) {
      // Loads for the previous user are not this one's.
      _loading = null;
      _loadedAt = null;
      if (userId == null) return;
      // The sign-in load; a load started since covers it.
      Future.microtask(() {
        if (ref.mounted && _loading == null) unawaited(refresh());
      });
    }, fireImmediately: true);
  }

  void _onForeground() {
    if (ref.read(currentUserIdProvider) == null) return;
    final loadedAt = _loadedAt;
    if (loadedAt != null &&
        _now().difference(loadedAt) <
            AppConstants.discoverNewsForegroundInterval) {
      return;
    }
    unawaited(refresh());
  }

  /// A push arrived while the app is open, or was opened: one routed to
  /// the Tipps or the Alternativen brings news of them, so they load; one
  /// routed to Entdecken brings a dietitian's tip, so the tips load (once
  /// they are loaded at all; their first load is still to come otherwise);
  /// others bring none.
  Future<void> pushArrived(String? route) => switch (route == null
      ? null
      : Uri.tryParse(route)?.path) {
    RoutePaths.recommendations || RoutePaths.ingredientSuggestions => refresh(),
    RoutePaths.discover when ref.read(dietitianTipsProvider.exists) =>
      ref.read(dietitianTipsProvider.notifier).refresh(),
    _ => Future.value(),
  };

  /// Entdecken's first load: joins a load under way (the sign-in load the
  /// app root just started); otherwise loads only while the tips or the
  /// Alternativen have no value yet (their first load failed).
  Future<void> ensureLoaded() {
    final loading = _loading;
    if (loading != null) return loading;
    final loaded =
        ref.read(recommendationProvider).hasValue &&
        ref.read(ingredientSuggestionProvider).hasValue;
    return loaded ? Future.value() : refresh();
  }

  /// Loads the tip sets and the Alternativen together. Each load is
  /// coalesced: a call while one runs (a push, a pull to refresh) makes
  /// exactly one more after it and completes once that one is done. Never
  /// throws.
  Future<void> refresh() async {
    if (!ref.mounted) return;
    final load = _loading = Future.wait([
      ref.read(recommendationProvider.notifier).fetchRecommendations(),
      ref.read(ingredientSuggestionProvider.notifier).fetchSuggestions(),
    ]);
    await load;
    if (!ref.mounted || !identical(_loading, load)) return;
    _loading = null;
    _loadedAt = _now();
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
