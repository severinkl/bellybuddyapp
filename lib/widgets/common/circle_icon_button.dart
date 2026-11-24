import 'package:material_ui/material_ui.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';

class CircleIconButton extends StatelessWidget {
  final Key? tapKey;
  final IconData icon;
  final double size;
  final Color? backgroundColor;
  final VoidCallback? onPressed;

  /// What VoiceOver/TalkBack call the button (the icon says nothing).
  final String semanticLabel;

  const CircleIconButton({
    super.key,
    this.tapKey,
    required this.icon,
    required this.semanticLabel,
    this.size = AppConstants.iconBadgeMd,
    this.backgroundColor,
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
        ),
        child: Icon(
          icon,
          color: onPressed != null
              ? AppTheme.foreground
              : AppTheme.mutedForeground,
          size: 24,
        ),
      ),
    );
  }
}
