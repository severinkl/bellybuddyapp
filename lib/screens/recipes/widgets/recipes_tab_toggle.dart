import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';

/// Two-segment (or N-segment) pill toggle without Material's checkmark.
/// Active segment paints a card-colored pill; inactive segments are flat.
class RecipesTabToggle extends StatelessWidget {
  const RecipesTabToggle({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final int value;
  final List<String> segments;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingXs),
      decoration: BoxDecoration(
        color: AppTheme.muted,
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      ),
      child: Row(
        children: [
          for (int i = 0; i < segments.length; i++)
            Expanded(
              child: _Segment(
                label: segments[i],
                active: i == value,
                onTap: () => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
        decoration: active
            ? BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.foreground.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              )
            : null,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? AppTheme.foreground : AppTheme.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
