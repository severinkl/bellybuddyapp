import 'package:flutter/material.dart';

/// Animates [controller] to [target] only if it's attached and not already
/// there. Safe to call from `ref.listen` callbacks — avoids redundant
/// animations when the controller is already at the target (e.g. when
/// `jumpToPage` just settled and fired `onPageChanged`).
void animatePageControllerTo(
  PageController controller,
  int target, {
  required Duration duration,
  Curve curve = Curves.easeOut,
}) {
  if (!controller.hasClients) return;
  final current = (controller.page ?? controller.initialPage.toDouble())
      .round();
  if (current == target) return;
  controller.animateToPage(target, duration: duration, curve: curve);
}
