import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';
import 'bb_slider.dart';
import 'mascot_image.dart';

class MoodSliderRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final String? leftLabel;
  final String rightLabel;
  final String leftMascot;
  final String rightMascot;
  final double mascotScale;

  const MoodSliderRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.leftLabel,
    required this.rightLabel,
    required this.leftMascot,
    required this.rightMascot,
    this.mascotScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final mascotSize = 48.0 * mascotScale;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticService.selection();
              onChanged(1);
            },
            child: MascotImage(
              assetPath: leftMascot,
              width: mascotSize,
              height: mascotSize,
            ),
          ),
          Expanded(
            child: BbSlider(
              value: value,
              variant: SliderVariant.danger,
              onChanged: onChanged,
              rightLabel: rightLabel,
              leftLabel: leftLabel,
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticService.selection();
              onChanged(5);
            },
            child: MascotImage(
              assetPath: rightMascot,
              width: mascotSize,
              height: mascotSize,
            ),
          ),
        ],
      ),
    );
  }
}
