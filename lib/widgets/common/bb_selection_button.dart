import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/haptic_service.dart';
import '../../config/constants.dart';

class BbSelectionButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;
  final Widget? leading;
  final double? height;

  const BbSelectionButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onPressed,
    this.leading,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: OutlinedButton(
          onPressed: () {
            HapticService.selection();
            onPressed();
          },
          style: OutlinedButton.styleFrom(
            backgroundColor:
                isSelected ? AppTheme.primary.withValues(alpha: 0.1) : null,
            side: BorderSide(
              color: isSelected ? AppTheme.primary : AppTheme.border,
              width: isSelected ? 2 : 1,
            ),
            padding: leading != null
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            ),
          ),
          child: leading != null
              ? Row(
                  children: [
                    leading!,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeSubtitle,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: AppTheme.foreground,
                        ),
                      ),
                    ),
                  ],
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeSubtitle,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: AppTheme.foreground,
                  ),
                ),
        ),
      ),
    );
  }
}
