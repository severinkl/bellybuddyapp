import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/relief_player_provider.dart';
import '../../../services/relief/relief_content.dart';
import '../../../widgets/common/bb_progress_bar.dart';
import 'breath_pacer.dart';

/// A running (or paused) exercise: „Schritt n von m", the total progress,
/// the step text, its remaining time or the pacer, and the controls pinned
/// at the bottom while the rest scrolls.
class ReliefRunningView extends StatelessWidget {
  const ReliefRunningView({
    super.key,
    required this.exercise,
    required this.state,
    required this.secondsLeftInStep,
    required this.secondsDone,
    required this.onBack,
    required this.onToggle,
    required this.onNext,
  });

  final ReliefExercise exercise;
  final ReliefPlayerState state;
  final int secondsLeftInStep;
  final int secondsDone;
  final VoidCallback onBack;
  final VoidCallback onToggle;
  final VoidCallback onNext;

  /// Text scales above this stack the controls instead of a row.
  static const _stackControlsAbove = 1.5;

  static String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final step = exercise.steps[state.stepIndex];
    final running = state.status == ReliefPlayerStatus.running;
    final breath = step.breath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          value: ReliefCopy.progressSemantics(
            secondsDone / exercise.totalSeconds,
          ),
          child: BbProgressBar(
            value: secondsDone / exercise.totalSeconds,
            height: AppConstants.reliefProgressHeight,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: AppConstants.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ReliefCopy.stepOf(state.stepIndex + 1, exercise.steps.length),
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                AppConstants.gap12,
                Text(
                  step.text,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeTitleLG,
                    height: AppTheme.lineHeightBody,
                    color: AppTheme.foreground,
                  ),
                ),
                AppConstants.gap24,
                if (breath != null) ...[
                  Center(
                    child: BreathPacer(
                      pattern: breath,
                      secondInStep: state.secondInStep,
                      running: running,
                    ),
                  ),
                  AppConstants.gap16,
                ],
                Text(
                  _clock(secondsLeftInStep),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: step.quiet
                        ? AppTheme.fontSizeStreakCount
                        : AppTheme.fontSizeHeading,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: AppConstants.paddingMd,
            child: _Controls(
              running: running,
              stacked:
                  MediaQuery.textScalerOf(context).scale(1) >
                  _stackControlsAbove,
              onBack: onBack,
              onToggle: onToggle,
              onNext: onNext,
            ),
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.running,
    required this.stacked,
    required this.onBack,
    required this.onToggle,
    required this.onNext,
  });

  final bool running;
  final bool stacked;
  final VoidCallback onBack;
  final VoidCallback onToggle;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    const minSize = AppConstants.minTapSize;
    final back = OutlinedButton(
      onPressed: onBack,
      style: OutlinedButton.styleFrom(minimumSize: minSize),
      child: const Text(ReliefCopy.back),
    );
    final toggle = FilledButton(
      onPressed: onToggle,
      style: FilledButton.styleFrom(minimumSize: minSize),
      child: Text(running ? ReliefCopy.pause : ReliefCopy.resume),
    );
    final next = OutlinedButton(
      onPressed: onNext,
      style: OutlinedButton.styleFrom(minimumSize: minSize),
      child: const Text(ReliefCopy.next),
    );
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          toggle,
          AppConstants.gap8,
          Row(
            children: [
              Expanded(child: back),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(child: next),
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: back),
        const SizedBox(width: AppConstants.spacingSm),
        Expanded(child: toggle),
        const SizedBox(width: AppConstants.spacingSm),
        Expanded(child: next),
      ],
    );
  }
}
