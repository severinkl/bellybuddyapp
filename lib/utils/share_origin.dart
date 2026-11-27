import 'package:flutter/widgets.dart';

/// The screen rect of the widget behind [context]: where iPad anchors the
/// share popover. [Rect.zero] without a laid-out render box.
Rect shareOriginOf(BuildContext? context) {
  final box = context?.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return Rect.zero;
  return box.localToGlobal(Offset.zero) & box.size;
}
