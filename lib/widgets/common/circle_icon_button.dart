import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';

class CircleIconButton extends StatelessWidget {
  final Key? tapKey;
  final IconData icon;
  final double size;
  final Color? backgroundColor;
  final VoidCallback? onPressed;

  const CircleIconButton({
    super.key,
    this.tapKey,
    required this.icon,
    this.size = AppConstants.iconBadgeMd,
    this.backgroundColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
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
