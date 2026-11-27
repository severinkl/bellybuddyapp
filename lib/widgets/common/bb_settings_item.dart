import 'package:material_ui/material_ui.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import 'bb_card.dart';
import 'press_scale_wrapper.dart';

class BbSettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// A small pill after the title (e.g. Neu).
  final String? badge;

  const BbSettingsItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return PressScaleWrapper(
      onTap: onTap,
      child: BbCard(
        color: Colors.white,
        showBorder: false,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: AppTheme.fontSizeSubtitle,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.foreground,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: AppConstants.spacingSm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.spacing6,
                            vertical: AppConstants.spacing2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.navBadge,
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusFull,
                            ),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              fontSize: AppTheme.fontSizeSM,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeCaptionLG,
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
