import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'route_names.dart';

extension BellyBuddyNavigation on BuildContext {
  /// Pops the current route, or falls back to `/dashboard` when the stack
  /// is empty. The fallback matters for deep-link starts (e.g. a push
  /// notification whose `data.route` points directly at a tracker): in that
  /// case `context.pop()` would throw a GoError.
  void popOrGoDashboard() => canPop() ? pop() : go(RoutePaths.dashboard);
}
