import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/bb_selection_button.dart';
import '../../../widgets/common/mascot_image.dart';

class DietStep extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const DietStep({super.key, this.value, required this.onChanged});

  static const _options = [
    ('alles', 'Alles'),
    ('vegetarisch', 'Vegetarisch'),
    ('vegan', 'Vegan'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppConstants.paddingLg,
      child: Column(
        children: [
          AppConstants.gap24,
          const MascotImage(assetPath: AppConstants.mascotHappy, width: 120, height: 120),
          AppConstants.gap16,
          const Text(
            'Wie ernährst du dich?',
            style: TextStyle(
              fontSize: AppTheme.fontSizeHeadingLG,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap8,
          const Text(
            'Diese Information hilft uns dir geeignete alternative Zutaten und Rezepte vorzuschlagen.',
            style: TextStyle(fontSize: AppTheme.fontSizeBodyLG, color: AppTheme.mutedForeground),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap32,
          ..._options.map((option) {
            return BbSelectionButton(
              label: option.$2,
              isSelected: value == option.$1,
              onPressed: () => onChanged(option.$1),
              height: 56,
            );
          }),
        ],
      ),
    );
  }
}
