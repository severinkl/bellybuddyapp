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
      padding: AppConstants.paddingLg,
      child: Column(
        children: [
          AppConstants.gap24,
          const MascotImage(
            assetPath: AppConstants.mascotWink,
            width: 120,
            height: 120,
          ),
          AppConstants.gap16,
          const Text(
            'Größe & Gewicht',
            style: TextStyle(
              fontSize: AppTheme.fontSizeHeadingLG,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap8,
          const Text(
            'Diese Angaben helfen uns dabei, deine Verdauung besser zu verstehen.',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBodyLG,
              color: AppTheme.mutedForeground,
            ),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap24,
          Expanded(
            child: Container(
              padding: AppConstants.paddingMd,
              decoration: BoxDecoration(
                color: AppTheme.beige,
                borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Größe',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeSubtitle,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.mutedForeground,
                          ),
                        ),
                        AppConstants.gap8,
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
                  const SizedBox(width: AppConstants.spacingLg),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Gewicht',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeSubtitle,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.mutedForeground,
                          ),
                        ),
                        AppConstants.gap8,
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
