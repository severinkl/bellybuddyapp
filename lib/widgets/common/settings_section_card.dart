import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
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
    final effectiveIconColor = iconColor ?? AppTheme.primary;
    final effectiveTitleColor = titleColor ?? AppTheme.foreground;

    return BbCard(
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: effectiveIconColor),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: effectiveTitleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
