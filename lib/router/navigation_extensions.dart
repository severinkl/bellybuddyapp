import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'route_names.dart';

extension BellyBuddyNavigation on BuildContext {
  /// Pops the current route, or goes to [location] when nothing is below.
  /// The fallback matters for deep-link starts (e.g. a push notification
  /// whose `data.route` points directly at a tracker): there
  /// `context.pop()` would throw a GoError.
  void popOr(String location) => canPop() ? pop() : go(location);

  /// [popOr] `/dashboard`.
  void popOrGoDashboard() => popOr(RoutePaths.dashboard);

  /// Pushes the collection recipe [recipeId] (its detail, without the bar).
  Future<void> openRecipe(String recipeId) =>
      push<void>(RoutePaths.collectionRecipeFor(recipeId));
}
