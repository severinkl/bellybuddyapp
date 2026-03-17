import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../widgets/common/mood_slider_row.dart';

class StimmungTab extends StatelessWidget {
  final int stress, happiness, energy, focus, bodyFeel;
  final ValueChanged<int> onStressChanged,
      onHappinessChanged,
      onEnergyChanged,
      onFocusChanged,
      onBodyFeelChanged;

  const StimmungTab({
    super.key,
    required this.stress,
    required this.happiness,
    required this.energy,
    required this.focus,
    required this.bodyFeel,
    required this.onStressChanged,
    required this.onHappinessChanged,
    required this.onEnergyChanged,
    required this.onFocusChanged,
    required this.onBodyFeelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Wie ist deine Stimmung?',
          style: TextStyle(
            fontSize: AppTheme.fontSizeTitleLG,
            fontWeight: FontWeight.w500,
          ),
        ),
        AppConstants.gap16,
        MoodSliderRow(
          value: stress,
          onChanged: onStressChanged,
          leftLabel: 'entspannt',
          rightLabel: 'gestresst',
          leftMascot: AppConstants.mascotHappy,
          rightMascot: AppConstants.mascotStressed,
        ),
        MoodSliderRow(
          value: happiness,
          onChanged: onHappinessChanged,
          leftLabel: 'glücklich',
          rightLabel: 'traurig',
          leftMascot: AppConstants.mascotHappy,
          rightMascot: AppConstants.mascotSad,
        ),
        MoodSliderRow(
          value: energy,
          onChanged: onEnergyChanged,
          leftLabel: 'energiegeladen',
          rightLabel: 'müde',
          leftMascot: AppConstants.mascotEnergetic,
          rightMascot: AppConstants.mascotBored,
        ),
        MoodSliderRow(
          value: focus,
          onChanged: onFocusChanged,
          leftLabel: 'fokussiert',
          rightLabel: 'unkonzentriert',
          leftMascot: AppConstants.mascotClear,
          rightMascot: AppConstants.mascotUnfocused,
        ),
        MoodSliderRow(
          value: bodyFeel,
          onChanged: onBodyFeelChanged,
          leftLabel: 'wohl',
          rightLabel: 'unwohl',
          leftMascot: AppConstants.mascotCool,
          rightMascot: AppConstants.mascotNervous,
        ),
      ],
    );
  }
}
