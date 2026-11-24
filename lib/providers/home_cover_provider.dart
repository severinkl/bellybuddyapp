import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';

/// Whether something covers Home, so the Buddy's cues and their sheets wait
/// (`BuddyHero`): they never stack on it, play behind it, nor open over a
/// page on its way in. The one tracker of what covers Home:
/// - a sheet opened over it ([whileOpen]: „Dein Streak", „Deine
///   Belohnungen" with what its row opens) until it is done;
/// - Home left ([leftHome]) for a page pushed over it until that page
///   closes, or for another tab; either until Home is hidden
///   ([homeHidden]; hidden, Home's own visibility holds the Buddy) or shown
///   again ([homeShown]).
///
/// Per signed-in user: another user starts uncovered.
class HomeCoverNotifier extends Notifier<bool> {
  final _sheets = <Object>{};
  final _pages = <Future<void>>{};

  /// Home was left for another tab, and not hidden or shown since.
  bool _leftForTab = false;

  @override
  bool build() {
    ref.watch(currentUserIdProvider);
    _sheets.clear();
    _pages.clear();
    _leftForTab = false;
    return false;
  }

  /// Covers Home, then runs [open] (a sheet and what follows it) until it
  /// is done, failed or not; completes with it, Home uncovered by then.
  Future<T> whileOpen<T>(Future<T> Function() open) async {
    final sheet = Object();
    _sheets.add(sheet);
    _update();
    try {
      return await open();
    } finally {
      _sheets.remove(sheet);
      _update();
    }
  }

  /// Home is left: for [page], pushed over it, until that page closes; for
  /// another tab (null). Either until Home is hidden or shown again.
  void leftHome(Future<void>? page) {
    if (page == null) {
      _leftForTab = true;
    } else {
      _pages.add(page);
      page.whenComplete(() {
        if (_pages.remove(page)) _update();
      }).ignore();
    }
    _update();
  }

  /// Home is hidden (under a page or another tab): what left it no longer
  /// covers it.
  void homeHidden() => _clearLeft();

  /// Home is shown again, or its route is on top again (a `go` that
  /// replaced a page on its way in, whose close never comes): what left it
  /// no longer covers it.
  void homeShown() => _clearLeft();

  void _clearLeft() {
    if (_pages.isEmpty && !_leftForTab) return;
    _pages.clear();
    _leftForTab = false;
    _update();
  }

  void _update() {
    if (ref.mounted) {
      state = _sheets.isNotEmpty || _pages.isNotEmpty || _leftForTab;
    }
  }
}

final homeCoveredProvider = NotifierProvider<HomeCoverNotifier, bool>(
  HomeCoverNotifier.new,
);
