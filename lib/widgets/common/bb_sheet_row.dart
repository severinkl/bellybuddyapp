import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';

/// Soft-elevated white card row used by selection bottom sheets.
/// Shape: `[leading] gap [Expanded(child)]`, tappable.
class BbSheetRow extends StatelessWidget {
  const BbSheetRow({
    super.key,
    required this.onTap,
    required this.leading,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget leading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppConstants.paddingSm,
          child: Row(
            children: [
              leading,
              const SizedBox(width: AppConstants.spacing12),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
