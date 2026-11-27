import 'package:material_ui/material_ui.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';

class CircleIconButton extends StatelessWidget {
  final Key? tapKey;
  final IconData icon;
  final double size;
  final double iconSize;
  final Color? backgroundColor;

  /// A soft drop shadow, for a button floating over a photo.
  final bool raised;
  final VoidCallback? onPressed;

  /// What VoiceOver/TalkBack call the button (the icon says nothing).
  final String semanticLabel;

  const CircleIconButton({
    super.key,
    this.tapKey,
    required this.icon,
    required this.semanticLabel,
    this.size = AppConstants.iconBadgeLg,
    this.iconSize = AppConstants.iconSizeMd,
    this.backgroundColor,
    this.raised = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: _button(),
    );
  }

  Widget _button() {
    return GestureDetector(
      key: tapKey,
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppTheme.beige,
          shape: BoxShape.circle,
          boxShadow: raised
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: AppConstants.shadowBlurSm,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: onPressed != null
              ? AppTheme.foreground
              : AppTheme.mutedForeground,
          size: iconSize,
        ),
      ),
    );
  }
}
