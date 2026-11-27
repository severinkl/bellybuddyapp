import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../services/relief/relief_content.dart';

/// A circle that grows over the inhale, stays during holds and shrinks over
/// the exhale, with the phase word and the seconds left in it in the middle.
/// Under „Bewegung reduzieren" the circle stays still and the word and
/// countdown carry it alone.
class BreathPacer extends StatefulWidget {
  const BreathPacer({
    super.key,
    required this.pattern,
    required this.secondInStep,
    required this.running,
  });

  static const circleKey = ValueKey('relief-pacer-circle');

  final BreathPattern pattern;
  final int secondInStep;

  /// While running the circle moves toward where the breath is at the end
  /// of the current second; paused, it holds where it is.
  final bool running;

  @override
  State<BreathPacer> createState() => _BreathPacerState();
}

/// How full the lungs are (0–1) at [second] of [pattern].
double _breathFill(BreathPattern pattern, int second) {
  final at = pattern.phaseProgressAt(second);
  return switch (at.phase) {
    BreathPhase.inhale => at.elapsed / at.length,
    BreathPhase.holdIn => 1,
    BreathPhase.exhale => 1 - at.elapsed / at.length,
    BreathPhase.holdOut => 0,
  };
}

class _BreathPacerState extends State<BreathPacer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    value: _target,
  );

  double get _target => _breathFill(
    widget.pattern,
    widget.running ? widget.secondInStep + 1 : widget.secondInStep,
  );

  @override
  void didUpdateWidget(BreathPacer old) {
    super.didUpdateWidget(old);
    if (old.secondInStep == widget.secondInStep &&
        old.running == widget.running &&
        old.pattern == widget.pattern) {
      return;
    }
    if (widget.running) {
      _fill.animateTo(_target, duration: AppConstants.reliefPacerTick);
    } else {
      // Hold where the circle is, not where the second began.
      if (old.running) {
        _fill.stop();
      } else {
        _fill.value = _target;
      }
    }
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final phase = widget.pattern.phaseAt(widget.secondInStep);
    final label = breathPhaseLabel(phase);
    final left = widget.pattern.secondsLeftInPhase(widget.secondInStep);
    return SizedBox.square(
      dimension: AppConstants.reliefPacerMax,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _fill,
            builder: (context, _) {
              final size = still
                  ? AppConstants.reliefPacerMax
                  : AppConstants.reliefPacerMin +
                        (AppConstants.reliefPacerMax -
                                AppConstants.reliefPacerMin) *
                            _fill.value;
              return Container(
                key: BreathPacer.circleKey,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primary,
                    width: AppConstants.spacingXs,
                  ),
                ),
              );
            },
          ),
          Semantics(
            container: true,
            label: ReliefCopy.phaseSemantics(label, left),
            child: ExcludeSemantics(
              child: Padding(
                padding: AppConstants.paddingLg,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: AppTheme.fontSizeHeading,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.foreground,
                        ),
                      ),
                      Text(
                        '$left',
                        style: const TextStyle(
                          fontSize: AppTheme.fontSizeDisplay,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
