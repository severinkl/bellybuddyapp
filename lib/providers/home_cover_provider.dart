import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart'
    show
        GlobalKey,
        NavigatorObserver,
        NavigatorState,
        PopupRoute,
        Route,
        VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';

/// Whether something covers Home, so the Buddy's cues and their sheets wait
/// (`BuddyHero`): they never stack on it, play behind it, nor open over a
/// page on its way in. The one tracker of what covers Home, from two
/// general signals and two flows they can't see:
/// - Home's route is not the router's top route ([homeCurrent], which the
///   hero follows): any page pushed over Home, from its push on (on its
///   way in too) until it is popped or replaced, and another tab;
/// - a sheet, dialog or menu is open over it ([HomeCoverObserver], on the
///   root navigator and Home's own): „Eintragen", „Dein Streak", the
///   Buddy's own sheets, …;
/// - a flow from Home is not done ([whileOpen]), also between its sheets
///   and while it still writes: „Dein Streak" until a goal picked there is
///   saved, „Deine Belohnungen" until what its row opens has opened, Home's
///   tour while it is up;
/// - something over the app until the user is back ([leftHome]): day 2's
///   article in the in-app browser.
///
/// Per signed-in user: another user starts uncovered.
class HomeCoverNotifier extends Notifier<bool> {
  final _flows = <Object>{};
  final _popups = <Route<dynamic>>{};
  final _away = <Future<void>>{};

  /// Home's route is not the router's top route.
  bool _notOnTop = false;

  @override
  bool build() {
    ref.watch(currentUserIdProvider);
    return false;
  }

  /// Covers Home, then runs [open] (a sheet and what follows it) until it
  /// is done, failed or not; completes with it, Home uncovered by then.
  Future<T> whileOpen<T>(Future<T> Function() open) async {
    final flow = Object();
    _flows.add(flow);
    _update();
    try {
      return await open();
    } finally {
      _flows.remove(flow);
      _update();
    }
  }

  /// Whether Home's route is the router's top route; not, Home is covered
  /// (a page over it, another tab).
  void homeCurrent(bool current) {
    if (_notOnTop == !current) return;
    _notOnTop = !current;
    _update();
  }

  /// [route], a sheet, dialog or menu, opened over Home
  /// ([HomeCoverObserver]); it covers Home until [popupClosed].
  void popupOpened(Route<dynamic> route) {
    if (_popups.add(route)) _update();
  }

  /// [route] closed or was removed.
  void popupClosed(Route<dynamic> route) {
    if (_popups.remove(route)) _update();
  }

  /// Home is left for something over the app that neither the router nor
  /// a navigator shows (the in-app browser), until [until] completes.
  void leftHome(Future<void> until) {
    _away.add(until);
    until.whenComplete(() {
      if (_away.remove(until)) _update();
    }).ignore();
    _update();
  }

  void _update() {
    if (!ref.mounted) return;
    final covered =
        _notOnTop ||
        _flows.isNotEmpty ||
        _popups.isNotEmpty ||
        _away.isNotEmpty;
    if (state != covered) state = covered;
  }
}

final homeCoveredProvider = NotifierProvider<HomeCoverNotifier, bool>(
  HomeCoverNotifier.new,
);

/// Tells [HomeCoverNotifier] which sheets, dialogs and menus ([PopupRoute])
/// are open over Home: those on [navigators] (the root navigator and
/// Home's own). Another tab's navigator is not watched: that tab hides Home
/// itself, and a sheet left open there must not cover Home once it is
/// back. Pages are the router's ([HomeCoverNotifier.homeCurrent]): they
/// are only built after the push, too late for what goes on right after.
///
/// Give it to the router (`GoRouter.observers`), which passes it on to the
/// tabs' navigators too.
class HomeCoverObserver extends NavigatorObserver {
  HomeCoverObserver(
    this._cover, {
    required List<GlobalKey<NavigatorState>> navigators,
  }) : _navigators = navigators;

  final HomeCoverNotifier Function() _cover;
  final List<GlobalKey<NavigatorState>> _navigators;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute && _watches(route)) {
      outsideBuild(() => _cover().popupOpened(route));
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _closed(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _closed(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _closed(oldRoute);
    if (newRoute != null) didPush(newRoute, oldRoute);
  }

  void _closed(Route<dynamic> route) {
    if (route is PopupRoute) outsideBuild(() => _cover().popupClosed(route));
  }

  bool _watches(Route<dynamic> route) {
    final navigator = route.navigator;
    return navigator != null &&
        _navigators.any((key) => identical(key.currentState, navigator));
  }
}

/// Runs [fn] now, or once the frame is done while the widget tree builds
/// (a navigator updating its pages): providers can't change then.
void outsideBuild(VoidCallback fn) {
  final scheduler = SchedulerBinding.instance;
  if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
    scheduler.addPostFrameCallback((_) => fn());
  } else {
    fn();
  }
}
