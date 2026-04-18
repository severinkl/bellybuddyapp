import 'dart:async';

import 'package:flutter/material.dart';

import 'dashboard_tutorial_overlay.dart';
import 'dashboard_tutorial_steps.dart';

/// Inserts the [DashboardTutorialOverlay] into the root Overlay using the
/// 10 predefined steps. Returns a Future that completes when the user either
/// finishes all steps or taps "Überspringen".
Future<void> showDashboardTutorial(BuildContext context) async {
  final completer = Completer<void>();
  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => DashboardTutorialOverlay(
      steps: dashboardTutorialSteps,
      onFinish: () {
        entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );

  Overlay.of(context, rootOverlay: true).insert(entry);
  return completer.future;
}
