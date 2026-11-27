import 'package:material_ui/material_ui.dart';

import '../../config/constants.dart';
import 'tap_target.dart';

/// An icon you tap: a named button with a hit area of at least
/// [AppConstants.minTapTarget] square around an icon drawn at [iconSize].
/// Disabled (to assistive tech too) while [onTap] is null.
class BbIconTap extends StatelessWidget {
  const BbIconTap({
    super.key,
    this.tapKey,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.iconSize = AppConstants.iconSizeMd,
    this.color,
  });

  final Key? tapKey;
  final IconData icon;

  /// What VoiceOver/TalkBack call the button (the icon says nothing).
  final String semanticLabel;
  final VoidCallback? onTap;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    enabled: onTap != null,
    label: semanticLabel,
    child: GestureDetector(
      key: tapKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: TapTarget(
        child: ExcludeSemantics(
          child: Icon(icon, size: iconSize, color: color),
        ),
      ),
    ),
  );
}
