import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import 'bb_card.dart';

class SettingsSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Color? iconColor;
  final Color? titleColor;
  final Color? cardColor;
  final Color? borderColor;

  const SettingsSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.iconColor,
    this.titleColor,
    this.cardColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AppTheme.foreground;
    final effectiveTitleColor = titleColor ?? AppTheme.foreground;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: effectiveIconColor),
            const SizedBox(width: AppConstants.spacingSm),
            Text(
              title,
              style: TextStyle(
                fontSize: AppTheme.fontSizeSubtitleLG,
                fontWeight: FontWeight.w700,
                color: effectiveTitleColor,
              ),
            ),
          ],
        ),
        AppConstants.gap10,
        BbCard(color: cardColor, child: child),
      ],
    );
  }
}
