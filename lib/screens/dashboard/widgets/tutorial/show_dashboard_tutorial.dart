import 'dart:async';

import 'package:flutter/material.dart';

import 'dashboard_tutorial_overlay.dart';
import 'dashboard_tutorial_steps.dart';

/// Handle for a running tutorial overlay. [future] completes when the user
/// finishes or skips the tour, OR when [cancel] is called (e.g. the host
/// screen is being disposed). [cancel] is a no-op once the overlay has
/// already finished.
class TutorialHandle {
  final Future<void> future;
  final VoidCallback cancel;

  const TutorialHandle({required this.future, required this.cancel});
}

/// Inserts the [DashboardTutorialOverlay] into the root Overlay using the
/// 10 predefined steps. Returns a [TutorialHandle] whose [TutorialHandle.cancel]
/// removes the overlay and completes the future — callers should invoke it
/// from their `dispose()` to avoid leaking the overlay + its animation
/// controller if the host widget is unmounted mid-tour.
TutorialHandle showDashboardTutorial(BuildContext context) {
  final completer = Completer<void>();
  late final OverlayEntry entry;
  var removed = false;

  void cleanup() {
    if (removed) return;
    removed = true;
    entry.remove();
    if (!completer.isCompleted) completer.complete();
  }

  entry = OverlayEntry(
    builder: (_) => DashboardTutorialOverlay(
      steps: dashboardTutorialSteps,
      onFinish: cleanup,
    ),
  );

  Overlay.of(context, rootOverlay: true).insert(entry);

  return TutorialHandle(future: completer.future, cancel: cleanup);
}
