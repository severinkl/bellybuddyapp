import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../services/recipes/recipe_fit.dart';

/// The pill of a [FitBadge]: „Passt zu dir" in green, the others in the
/// neutral tint with a warning mark.
class FitBadgeView extends StatelessWidget {
  const FitBadgeView(this.badge, {super.key, this.small = false});

  final FitBadge badge;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final fits = badge is FitsBadge;
    final color = fits
        ? AppTheme.gutFeelingGoodText
        : AppTheme.gutFeelingNeutralText;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fits
            ? AppTheme.gutFeelingGoodSoft
            : AppTheme.gutFeelingNeutralSoft,
        borderRadius: BorderRadius.circular(AppConstants.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing10,
          vertical: AppConstants.spacingXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              fits ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              size: AppConstants.iconSizeXs,
              color: color,
            ),
            const SizedBox(width: AppConstants.spacingXs),
            Flexible(
              child: Text(
                badge.label,
                style: TextStyle(
                  fontSize: small
                      ? AppTheme.fontSizeSM
                      : AppTheme.fontSizeCaption,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
