import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../models/recommendation_item.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../config/constants.dart';

class RecommendationCard extends StatelessWidget {
  final RecommendationItem item;
  final bool compact;

  const RecommendationCard({
    super.key,
    required this.item,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSubstitute = item.isSubstitute;
    final bgColor = isSubstitute
        ? AppTheme.warning.withValues(alpha: 0.1)
        : AppTheme.success.withValues(alpha: 0.1);
    final accentColor = isSubstitute ? AppTheme.warning : AppTheme.success;
    final icon = isSubstitute ? Icons.swap_horiz : Icons.eco;
    final label = isSubstitute ? 'Ersetzen' : 'Probieren';

    return BbCard(
      color: bgColor,
      showBorder: false,
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: compact ? 18 : 20, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.ingredient,
                  style: TextStyle(
                    fontSize: compact
                        ? AppTheme.fontSizeBody
                        : AppTheme.fontSizeSubtitle,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeCaption,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            item.reason,
            style: TextStyle(
              fontSize: compact
                  ? AppTheme.fontSizeCaptionLG
                  : AppTheme.fontSizeBody,
              color: AppTheme.mutedForeground,
            ),
          ),
          if (item.alternative != null) ...[
            SizedBox(height: compact ? 4 : 6),
            Text(
              '\u2192 Alternative: ${item.alternative}',
              style: TextStyle(
                fontSize: compact
                    ? AppTheme.fontSizeCaptionLG
                    : AppTheme.fontSizeBody,
                fontWeight: FontWeight.w500,
                color: AppTheme.success,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
