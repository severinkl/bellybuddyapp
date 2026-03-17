import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../config/app_theme.dart';
import 'press_scale_wrapper.dart';
import '../../config/constants.dart';

class TrackerCard extends StatelessWidget {
  final String svgPath;
  final String label;
  final VoidCallback onTap;

  const TrackerCard({
    super.key,
    required this.svgPath,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScaleWrapper(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
        padding: AppConstants.paddingLg,
        decoration: BoxDecoration(
          color: AppTheme.beige,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(svgPath, width: 48, height: 48),
            AppConstants.gap12,
            Text(
              label,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeSubtitleLG,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
              ),
            ),
            const Text(
              'Tracker',
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                color: AppTheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
