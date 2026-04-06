import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../widgets/common/press_scale_wrapper.dart';
import '../../../config/constants.dart';

class FeatureCard extends StatelessWidget {
  final String imageAsset;
  final String label;
  final IconData icon;
  final Color iconColor;
  final int badgeCount;
  final bool hasNew;
  final VoidCallback onTap;

  const FeatureCard({
    super.key,
    required this.imageAsset,
    required this.label,
    required this.icon,
    required this.iconColor,
    this.badgeCount = 0,
    this.hasNew = false,
    required this.onTap,
  });

  static const _borderWidth = 3.0;

  bool get _showBorder => hasNew || badgeCount > 0;

  @override
  Widget build(BuildContext context) {
    return PressScaleWrapper(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: _showBorder
              ? Border.all(color: AppTheme.primary, width: _borderWidth)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            _showBorder
                ? AppConstants.radiusLg - _borderWidth
                : AppConstants.radiusLg,
          ),
          child: SizedBox(
            height: 128,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(imageAsset, fit: BoxFit.cover),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                if (hasNew || badgeCount > 0)
                  Positioned(
                    top: AppConstants.spacingSm,
                    right: AppConstants.spacingSm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingSm,
                        vertical: AppConstants.spacingXs,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusMd,
                        ),
                      ),
                      child: Text(
                        hasNew ? 'Neu' : '$badgeCount',
                        style: const TextStyle(
                          fontSize: AppTheme.fontSizeCaption,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.foreground,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: AppConstants.spacing10,
                  left: AppConstants.spacing10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacing10,
                      vertical: AppConstants.spacing6,
                    ),
                    decoration: BoxDecoration(
                      color: _showBorder
                          ? AppTheme.primary
                          : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusRound,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: AppConstants.iconSizeXs,
                          color: iconColor,
                        ),
                        const SizedBox(width: AppConstants.spacingXs),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: AppTheme.fontSizeBodyLG,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.foreground,
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacing2),
                        const Icon(
                          Icons.chevron_right,
                          size: AppConstants.spacing14,
                          color: AppTheme.mutedForeground,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
