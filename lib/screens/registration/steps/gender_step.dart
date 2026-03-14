import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/bb_selection_button.dart';
import '../../../widgets/common/mascot_image.dart';

class GenderStep extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const GenderStep({super.key, this.value, required this.onChanged});

  static const _options = [
    ('weiblich', 'Weiblich'),
    ('männlich', 'Männlich'),
    ('andere', 'Andere'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const MascotImage(assetPath: AppConstants.mascotCool, width: 120, height: 120),
          const SizedBox(height: 16),
          const Text(
            'Wie lautet dein biologisches Geschlecht?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Diese Information wird für eine personalisierte Analyse verwendet.',
            style: TextStyle(fontSize: 15, color: AppTheme.mutedForeground),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
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
