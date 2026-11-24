import 'package:material_ui/material_ui.dart';
import '../../../config/app_theme.dart';
import '../../../models/recommendation_item.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../config/constants.dart';
import 'tip_recipe_link.dart';

class RecommendationCard extends StatelessWidget {
  final RecommendationItem item;
  final bool compact;

  /// „Fokus der Woche": a label above the header and a border.
  final bool focus;

  const RecommendationCard({
    super.key,
    required this.item,
    this.compact = false,
    this.focus = false,
  });

  /// The „Fokus der Woche" label.
  static const focusLabelKey = Key('recommendation_focus_label');

  @override
  Widget build(BuildContext context) {
    final isSubstitute = item.isSubstitute;
    final bgColor = isSubstitute
        ? AppTheme.warning.withValues(alpha: 0.1)
        : AppTheme.success.withValues(alpha: 0.1);
    final accentColor = isSubstitute ? AppTheme.warning : AppTheme.success;
    final icon = isSubstitute ? Icons.swap_horiz : Icons.eco;
    final label = isSubstitute ? 'Ersetzen' : 'Probieren';
    final recipeId = item.hasRecipeLink ? item.recipeId : null;

    return BbCard(
      color: bgColor,
      showBorder: focus,
      borderColor: AppTheme.primary,
      borderWidth: AppConstants.borderWidthLg,
      padding: EdgeInsets.all(
        compact ? AppConstants.spacing12 : AppConstants.spacingMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (focus) ...[
            const _FocusLabel(key: focusLabelKey),
            AppConstants.gap8,
          ],
          Row(
            children: [
              Icon(
                icon,
                size: compact
                    ? AppConstants.iconSizeSm
                    : AppConstants.iconSizeClose,
                color: accentColor,
              ),
              const SizedBox(width: AppConstants.spacingSm),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacing10,
                  vertical: AppConstants.spacingXs,
                ),
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
          SizedBox(
            height: compact ? AppConstants.spacing6 : AppConstants.spacingSm,
          ),
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
            SizedBox(
              height: compact ? AppConstants.spacingXs : AppConstants.spacing6,
            ),
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
          if (recipeId != null)
            TipRecipeLink(recipeId: recipeId, title: item.recipeTitle),
        ],
      ),
    );
  }
}

/// The „Fokus der Woche" pill.
class _FocusLabel extends StatelessWidget {
  const _FocusLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppConstants.spacing10,
          vertical: AppConstants.spacingXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              size: AppConstants.iconSizeXs,
              color: AppTheme.foreground,
            ),
            SizedBox(width: AppConstants.spacingXs),
            Flexible(
              child: Text(
                'Fokus der Woche',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeCaption,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
