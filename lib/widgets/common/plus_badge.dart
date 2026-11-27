import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../services/plus/plus_copy.dart';

/// The small „Plus" badge on a button whose feature needs Belly Buddy Plus
/// while it is locked (spec 4.4).
class PlusBadge extends StatelessWidget {
  const PlusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacing6,
        vertical: AppConstants.spacing2,
      ),
      decoration: BoxDecoration(
        color: AppTheme.plusBadge,
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: const Text(
        PlusCopy.plusBadge,
        style: TextStyle(
          fontSize: AppTheme.fontSizeSM,
          fontWeight: FontWeight.w700,
          color: AppTheme.plusBadgeForeground,
        ),
      ),
    );
  }
}
