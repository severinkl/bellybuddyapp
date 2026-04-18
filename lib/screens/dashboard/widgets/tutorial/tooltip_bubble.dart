import 'package:flutter/material.dart';

import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';

/// Speech-bubble style tooltip used by the onboarding overlay.
///
/// Renders [richText] inside a rounded-rectangle container with a soft shadow.
/// Width is capped at [maxWidth] logical pixels so the bubble never touches
/// the screen edges.
class TooltipBubble extends StatelessWidget {
  final List<InlineSpan> richText;
  final double maxWidth;

  const TooltipBubble({
    super.key,
    required this.richText,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: AppConstants.paddingMd,
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(children: richText),
      ),
    );
  }
}
