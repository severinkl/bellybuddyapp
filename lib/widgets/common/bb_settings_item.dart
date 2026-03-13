import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import 'bb_card.dart';
import 'press_scale_wrapper.dart';

class BbSettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const BbSettingsItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScaleWrapper(
      onTap: onTap,
      child: BbCard(
        child: Row(
          children: [
            Icon(icon, color: AppTheme.foreground, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.mutedForeground),
          ],
        ),
      ),
    );
  }
}
