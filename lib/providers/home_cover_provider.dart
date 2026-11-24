import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';

/// Whether something Home's content opened covers Home, so the Buddy's own
/// sheets wait (`BuddyHero`): they never stack on it, nor open over a page
/// on its way in.
/// - A sheet ([whileOpen], „Deine Belohnungen" with what its row opens)
///   covers Home until it is done.
/// - A page it opened over Home ([leftHome]) covers it until the page
///   closes or Home is hidden under it ([homeHidden]); hidden, Home's own
///   visibility holds the Buddy's sheets.
///
/// Per signed-in user: another user starts uncovered.
class HomeCoverNotifier extends Notifier<bool> {
  final _sheets = <Object>{};
  final _pages = <Future<void>>{};

  @override
  bool build() {
    ref.watch(currentUserIdProvider);
    _sheets.clear();
    _pages.clear();
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

  /// Told that a reward left Home (a `LeavingHome`): [page] covers it until
  /// it closes or Home is hidden; another tab (null) hides Home at once.
  void leftHome(Future<void>? page) {
    if (page == null) return;
    _pages.add(page);
    _update();
    page.whenComplete(() {
      _pages.remove(page);
      _update();
    }).ignore();
  }

  /// Home is hidden (under a page or another tab): no page covers it now.
  void homeHidden() {
    if (_pages.isEmpty) return;
    _pages.clear();
    _update();
  }

  void _update() {
    if (ref.mounted) state = _sheets.isNotEmpty || _pages.isNotEmpty;
  }
}

final homeCoveredProvider = NotifierProvider<HomeCoverNotifier, bool>(
  HomeCoverNotifier.new,
);
