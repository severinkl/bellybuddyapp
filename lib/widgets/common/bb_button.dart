import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/haptic_service.dart';

class BbButton extends StatelessWidget {
  final Key? tapKey;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final bool isDestructive;
  final bool isSecondary;
  final IconData? icon;

  const BbButton({
    super.key,
    required this.label,
    this.tapKey,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.isDestructive = false,
    this.isSecondary = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading
        ? null
        : onPressed != null
        ? () {
            HapticService.light();
            onPressed!();
          }
        : null;

    final child = isLoading
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : icon != null
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(label),
            ],
          )
        : Text(label);

    if (isOutlined) {
      return OutlinedButton(
        onPressed: effectiveOnPressed,
        style: isDestructive
            ? OutlinedButton.styleFrom(
                foregroundColor: AppTheme.destructive,
                side: const BorderSide(color: AppTheme.destructive),
              )
            : null,
        child: child,
      );
    }

    return ElevatedButton(
      key: tapKey,
      onPressed: effectiveOnPressed,
      style: isDestructive
          ? ElevatedButton.styleFrom(
              backgroundColor: AppTheme.destructive,
              foregroundColor: Colors.white,
            )
          : isSecondary
          ? ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondary,
              foregroundColor: AppTheme.secondaryForeground,
            )
          : null,
      child: child,
    );
  }
}
