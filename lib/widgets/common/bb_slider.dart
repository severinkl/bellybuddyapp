import 'package:material_ui/material_ui.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../services/haptic_service.dart';

enum SliderVariant { normal, danger, stool }

class BbSlider extends StatelessWidget {
  /// The selected value; null while the user hasn't set one (an optional
  /// rating): the thumb then rests at [min] in muted colors, and any touch,
  /// even on [min], sets it.
  final int? value;
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

  static const _labelStyle = TextStyle(
    fontSize: AppTheme.fontSizeCaption,
    color: AppTheme.mutedForeground,
  );

  Color _getTrackColor() {
    final value = this.value;
    if (value == null) return AppTheme.mutedForeground;
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
            value: (value ?? min).toDouble(),
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
            // Slider reports no change for a touch on the value it shows,
            // so an unset slider touched at [min] is set when let go.
            onChangeEnd: value == null
                ? (v) {
                    HapticService.selection();
                    onChanged(v.round());
                  }
                : null,
          ),
        ),
        if (leftLabel != null || centerLabel != null || rightLabel != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // Labels wrap instead of overflowing on narrow screens or with
            // larger text.
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(child: Text(leftLabel ?? '', style: _labelStyle)),
                if (centerLabel != null) ...[
                  const SizedBox(width: AppConstants.spacingXs),
                  Flexible(
                    child: Text(
                      centerLabel!,
                      style: _labelStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(width: AppConstants.spacingXs),
                Flexible(
                  child: Text(
                    rightLabel ?? '',
                    style: _labelStyle,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
