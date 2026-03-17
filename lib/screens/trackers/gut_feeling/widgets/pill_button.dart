import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../services/haptic_service.dart';

class PillButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const PillButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading
          ? null
          : () {
              HapticService.light();
              onPressed();
            },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isLoading
              ? AppTheme.primary.withValues(alpha: 0.7)
              : AppTheme.primary,
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryForeground,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeTitle,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryForeground,
                  ),
                ),
        ),
      ),
    );
  }
}
