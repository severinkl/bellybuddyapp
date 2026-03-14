import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/haptic_service.dart';

enum SliderVariant { normal, danger, stool }

class BbSlider extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final SliderVariant variant;
  final String? leftLabel;
  final String? centerLabel;
  final String? rightLabel;

  const BbSlider({
    super.key,
    required this.value,
    this.min = 1,
    this.max = 5,
    required this.onChanged,
    this.variant = SliderVariant.normal,
    this.leftLabel,
    this.centerLabel,
    this.rightLabel,
  });

  Color _getTrackColor() {
    switch (variant) {
      case SliderVariant.danger:
        return AppTheme.dangerSliderColor(value.toDouble(), maxValue: max);
      case SliderVariant.stool:
        return AppTheme.stoolColor(value);
      case SliderVariant.normal:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: _getTrackColor(),
            inactiveTrackColor: AppTheme.muted,
            thumbColor: _getTrackColor(),
            overlayColor: _getTrackColor().withValues(alpha: 0.2),
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) {
              final newValue = v.round();
              if (newValue != value) {
                HapticService.selection();
                onChanged(newValue);
              }
            },
          ),
        ),
        if (leftLabel != null || centerLabel != null || rightLabel != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  leftLabel ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                if (centerLabel != null)
                  Text(
                    centerLabel!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                Text(
                  rightLabel ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
