import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../services/haptic_service.dart';

class BbSocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;

  const BbSocialButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor = Colors.white,
    this.textColor = AppTheme.foreground,
    this.borderColor,
  });

  factory BbSocialButton.google({Key? key, required VoidCallback? onPressed}) {
    return BbSocialButton(
      key: key,
      label: 'Mit Google fortfahren',
      icon: const Text(
        'G',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4285F4),
        ),
      ),
      onPressed: onPressed,
      backgroundColor: Colors.white,
      textColor: AppTheme.foreground,
      borderColor: AppTheme.border,
    );
  }

  factory BbSocialButton.apple({Key? key, required VoidCallback? onPressed}) {
    return BbSocialButton(
      key: key,
      label: 'Mit Apple fortfahren',
      icon: const Icon(Icons.apple, color: AppTheme.foreground, size: 22),
      onPressed: onPressed,
      backgroundColor: Colors.white,
      textColor: AppTheme.foreground,
      borderColor: AppTheme.border,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed == null
            ? null
            : () {
                HapticService.light();
                onPressed!();
              },
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          side: BorderSide(color: borderColor ?? backgroundColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
