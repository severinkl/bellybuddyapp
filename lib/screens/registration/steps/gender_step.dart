import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/bb_selection_button.dart';
import '../../../widgets/common/mascot_image.dart';

class GenderStep extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  static const genderTitleKey = Key('gender_title');
  static const genderWeiblichKey = Key('gender_weiblich');
  static const genderMaennlichKey = Key('gender_maennlich');
  static const genderAndereKey = Key('gender_andere');

  const GenderStep({super.key, this.value, required this.onChanged});

  static const _options = [
    ('weiblich', 'Weiblich', 'gender_weiblich'),
    ('männlich', 'Männlich', 'gender_maennlich'),
    ('andere', 'Andere', 'gender_andere'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppConstants.paddingLg,
      child: Column(
        children: [
          AppConstants.gap24,
          const MascotImage(
            assetPath: AppConstants.mascotCool,
            width: 120,
            height: 120,
          ),
          AppConstants.gap16,
          const Text(
            key: genderTitleKey,
            'Wie lautet dein biologisches Geschlecht?',
            style: TextStyle(
              fontSize: AppTheme.fontSizeHeadingLG,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap8,
          const Text(
            'Diese Information wird für eine personalisierte Analyse verwendet.',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBodyLG,
              color: AppTheme.mutedForeground,
            ),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap32,
          ..._options.map((option) {
            return BbSelectionButton(
              selectionKey: Key(option.$3),
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
