import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../router/route_names.dart';
import '../../services/plus/plus_copy.dart';

/// Core refused a new share because it needs Belly Buddy Plus (402
/// `plus_required`, the app's lock state was stale): the paywall takes the
/// place of the form [route], so back from it lands on the list. Already
/// left (or no longer on top), core's [message] says it instead.
void replaceWithPlus(
  GoRouter router,
  ModalRoute<Object?>? route,
  ScaffoldMessengerState messenger,
  String? message,
) {
  if (route?.isCurrent ?? false) {
    unawaited(router.pushReplacement(RoutePaths.plus));
    return;
  }
  messenger.showSnackBar(
    SnackBar(content: Text(message ?? PlusCopy.plusRequired)),
  );
}
