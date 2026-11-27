import 'package:material_ui/material_ui.dart';

import 'tap_target.dart';

/// Something you tap that is one button to assistive tech: a single node
/// (named by [label], or by the text in [child] unless [excludeChild]),
/// disabled while [onTap] is null, with [selected], [value] and [expanded]
/// as given and, with [exclusive], part of a one-of group. [tapTarget] pads
/// the hit area to 48×48 ([TapTarget]); the whole area takes taps.
class BbTapArea extends StatelessWidget {
  const BbTapArea({
    super.key,
    this.tapKey,
    required this.onTap,
    required this.child,
    this.label,
    this.value,
    this.selected,
    this.exclusive = false,
    this.expanded,
    this.tapTarget = true,
    this.excludeChild = false,
  });

  /// Key on the gesture detector (what tests tap).
  final Key? tapKey;
  final VoidCallback? onTap;
  final Widget child;
  final String? label;
  final String? value;
  final bool? selected;

  /// One choice of several (a radio-like group).
  final bool exclusive;
  final bool? expanded;
  final bool tapTarget;

  /// Hides [child]'s own semantics: [label]/[value] say it all.
  final bool excludeChild;

  @override
  Widget build(BuildContext context) {
    Widget content = excludeChild ? ExcludeSemantics(child: child) : child;
    if (tapTarget) content = TapTarget(child: content);
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      selected: selected,
      inMutuallyExclusiveGroup: exclusive ? true : null,
      expanded: expanded,
      label: label,
      value: value,
      child: GestureDetector(
        key: tapKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      ),
    );
  }
}
