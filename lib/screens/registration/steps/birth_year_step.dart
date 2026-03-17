import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/bb_scroll_picker.dart';
import '../../../widgets/common/mascot_image.dart';

class BirthYearStep extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onChanged;

  const BirthYearStep({super.key, this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(100, (i) => currentYear - 10 - i);

    return Padding(
      padding: AppConstants.paddingLg,
      child: Column(
        children: [
          AppConstants.gap24,
          const MascotImage(
            assetPath: AppConstants.mascotHappy,
            width: 120,
            height: 120,
          ),
          AppConstants.gap16,
          const Text(
            'Wann wurdest du geboren?',
            style: TextStyle(
              fontSize: AppTheme.fontSizeHeadingLG,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap8,
          const Text(
            'Diese Information hilft uns dabei, deine Verdauung besser zu analysieren.',
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
                borderRadius: BorderRadius.circular(24),
              ),
              child: BbScrollPicker(
                items: years,
                selectedValue: value,
                onChanged: onChanged,
                expand: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
