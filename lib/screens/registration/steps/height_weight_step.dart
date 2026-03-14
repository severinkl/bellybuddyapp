import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/bb_scroll_picker.dart';
import '../../../widgets/common/mascot_image.dart';

class HeightWeightStep extends StatelessWidget {
  final int? height;
  final int? weight;
  final ValueChanged<int> onHeightChanged;
  final ValueChanged<int> onWeightChanged;

  const HeightWeightStep({
    super.key,
    this.height,
    this.weight,
    required this.onHeightChanged,
    required this.onWeightChanged,
  });

  @override
  Widget build(BuildContext context) {
    final heights = List.generate(100, (i) => 120 + i);
    final weights = List.generate(150, (i) => 30 + i);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const MascotImage(assetPath: AppConstants.mascotWink, width: 120, height: 120),
          const SizedBox(height: 16),
          const Text(
            'Größe & Gewicht',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Diese Angaben helfen uns dabei, deine Verdauung besser zu verstehen.',
            style: TextStyle(fontSize: 15, color: AppTheme.mutedForeground),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.beige,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Größe',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: BbScrollPicker(
                            items: heights,
                            selectedValue: height ?? 170,
                            onChanged: onHeightChanged,
                            labelBuilder: (v) => '$v cm',
                            expand: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Gewicht',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: BbScrollPicker(
                            items: weights,
                            selectedValue: weight ?? 70,
                            onChanged: onWeightChanged,
                            labelBuilder: (v) => '$v kg',
                            expand: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
