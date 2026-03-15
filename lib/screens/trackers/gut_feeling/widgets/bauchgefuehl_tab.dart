import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../widgets/common/mood_slider_row.dart';

class BauchgefuehlTab extends StatelessWidget {
  final int bloating, gas, cramps, fullness;
  final ValueChanged<int> onBloatingChanged, onGasChanged, onCrampsChanged, onFullnessChanged;

  const BauchgefuehlTab({
    super.key,
    required this.bloating,
    required this.gas,
    required this.cramps,
    required this.fullness,
    required this.onBloatingChanged,
    required this.onGasChanged,
    required this.onCrampsChanged,
    required this.onFullnessChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Wie ist dein Bauchgefühl?',
          style: TextStyle(fontSize: AppTheme.fontSizeTitleLG, fontWeight: FontWeight.w500),
        ),
        AppConstants.gap16,
        MoodSliderRow(
          value: bloating,
          onChanged: onBloatingChanged,
          rightLabel: AppConstants.gutFeelingSymptoms[0],
          leftMascot: AppConstants.mascotHappyStomach,
          rightMascot: AppConstants.mascotBloatingStomach,
          mascotFit: BoxFit.cover,
        ),
        MoodSliderRow(
          value: gas,
          onChanged: onGasChanged,
          rightLabel: AppConstants.gutFeelingSymptoms[1],
          leftMascot: AppConstants.mascotZen,
          rightMascot: AppConstants.mascotFlatulance,
          mascotFit: BoxFit.cover,
        ),
        MoodSliderRow(
          value: cramps,
          onChanged: onCrampsChanged,
          rightLabel: AppConstants.gutFeelingSymptoms[2],
          leftMascot: AppConstants.mascotNoCramp,
          rightMascot: AppConstants.mascotCramp,
          mascotFit: BoxFit.cover,
        ),
        MoodSliderRow(
          value: fullness,
          onChanged: onFullnessChanged,
          rightLabel: AppConstants.gutFeelingSymptoms[3],
          leftMascot: AppConstants.mascotInLove,
          rightMascot: AppConstants.mascotFullness,
          mascotFit: BoxFit.cover,
        ),
      ],
    );
  }
}
