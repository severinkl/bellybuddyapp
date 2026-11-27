import 'package:material_ui/material_ui.dart';

import '../../config/constants.dart';

/// Pads [child]'s hit area up to [AppConstants.minTapTarget] in both
/// directions without drawing anything: the child keeps its size and sits at
/// [alignment] inside the larger box, and the whole box counts for taps of
/// an enclosing gesture detector.
class TapTarget extends StatelessWidget {
  const TapTarget({
    super.key,
    required this.child,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => MetaData(
    // Opaque so a tap in the padding (where the child draws nothing) still
    // reaches the enclosing detector.
    behavior: HitTestBehavior.opaque,
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: AppConstants.minTapTarget,
        minHeight: AppConstants.minTapTarget,
      ),
      child: Align(
        alignment: alignment,
        widthFactor: 1,
        heightFactor: 1,
        child: child,
      ),
    ),
  );
}
