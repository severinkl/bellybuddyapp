import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';

/// Slim caption-styled pill for ingredient labels in selection sheets.
class BbIngredientChip extends StatelessWidget {
  const BbIngredientChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacing2,
      ),
      decoration: BoxDecoration(
        color: AppTheme.muted,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: AppTheme.fontSizeCaption,
          color: AppTheme.mutedForeground,
        ),
      ),
    );
  }
}
