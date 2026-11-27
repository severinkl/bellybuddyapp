import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../router/route_names.dart';
import '../../services/plus/plus_copy.dart';

/// Core refused something because it needs Belly Buddy Plus (402
/// `plus_required`, the app's lock state was stale): the paywall takes the
/// place of [route], so back from it lands on the screen below. True when it
/// did.
///
/// Only while this app run's Plus switch is on ([paywallOn]): with it off
/// (core enforces already, or the config could not be read) the router
/// sends `/plus` to Home, so the screen stays. Nor when [route] is gone or
/// no longer on top: go_router replaces the top route, whichever it is.
bool showPlusInstead({
  required bool paywallOn,
  required GoRouter router,
  required ModalRoute<Object?>? route,
}) {
  if (!paywallOn || !(route?.isCurrent ?? false)) return false;
  unawaited(router.pushReplacement(RoutePaths.plus));
  return true;
}

/// [showPlusInstead] for a form (a new share): when the paywall does not
/// take its place, core's [message] (else [PlusCopy.plusRequired]) says it
/// in a snack bar, and the form stays.
void replaceWithPlus(
  GoRouter router,
  ModalRoute<Object?>? route,
  ScaffoldMessengerState messenger,
  String? message, {
  required bool paywallOn,
}) {
  if (showPlusInstead(paywallOn: paywallOn, router: router, route: route)) {
    return;
  }
  messenger.showSnackBar(
    SnackBar(content: Text(message ?? PlusCopy.plusRequired)),
  );
}
