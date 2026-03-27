import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds a route to navigate to after the app is fully built.
/// Set when the app is launched by tapping a notification while terminated.
/// Consumed once by app.dart on first build.
class PendingRouteNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String route) => state = route;

  String? consume() {
    final route = state;
    state = null;
    return route;
  }
}

final pendingRouteProvider = NotifierProvider<PendingRouteNotifier, String?>(
  PendingRouteNotifier.new,
);
