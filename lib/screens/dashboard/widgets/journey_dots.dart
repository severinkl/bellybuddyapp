import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/insights.dart';
import '../../../widgets/buddy/buddy_controller.dart';
import '../../../widgets/buddy/buddy_painter.dart';
import '../../../widgets/buddy/buddy_pose.dart';

/// The first-patterns journey: 7 slots over a track, one filled dot per
/// day with entries (a green pip under a day with a Bauchgefühl) and a still
/// Buddy standing on the last filled dot. A dot that fills while shown
/// bumps once, but not with reduced motion.
///
/// Silent to a screen reader: the card's counters speak.
class JourneyDots extends StatefulWidget {
  const JourneyDots({super.key, required this.days});

  /// The latest active days, oldest first (at most [slots]).
  final List<JourneyDay> days;

  static const slots = 7;

  static Key dotKey(int i) => Key('journey_dot_$i');
  static const buddyKey = Key('journey_buddy');
  static const pipKey = Key('journey_pip');

  @override
  State<JourneyDots> createState() => _JourneyDotsState();
}

class _JourneyDotsState extends State<JourneyDots>
    with SingleTickerProviderStateMixin {
  /// Never ticked: the Buddy stands still.
  final _buddy = BuddyController(mood: BuddyMood.happy);

  late final AnimationController _bump = AnimationController(
    vsync: this,
    duration: AppConstants.journeyDotBump,
  );
  static final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.14), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.14, end: 1.0), weight: 1),
  ]);

  int _bumped = -1;

  @override
  void didUpdateWidget(JourneyDots old) {
    super.didUpdateWidget(old);
    final n = widget.days.length;
    if (n > old.days.length && n <= JourneyDots.slots) {
      if (MediaQuery.disableAnimationsOf(context)) return;
      _bumped = n - 1;
      _bump.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bump.dispose();
    _buddy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const dot = AppConstants.journeyDotSize;
    const pip = AppConstants.journeyPipSize;
    final filled = widget.days.length.clamp(0, JourneyDots.slots);
    final standOn = filled == 0 ? 0 : filled - 1;
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) {
          // Dot centres: the first and last dot touch the edges.
          final step = (box.maxWidth - dot) / (JourneyDots.slots - 1);
          double centre(int i) => dot / 2 + i * step;
          return SizedBox(
            height:
                AppConstants.journeyBuddyHeight +
                dot +
                AppConstants.spacing2 +
                pip,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned(
                  left: dot / 2,
                  right: dot / 2,
                  top:
                      AppConstants.journeyBuddyHeight +
                      (dot - AppConstants.journeyTrackHeight) / 2,
                  height: AppConstants.journeyTrackHeight,
                  child: ColoredBox(color: AppTheme.muted),
                ),
                for (var i = 0; i < JourneyDots.slots; i++)
                  Positioned(
                    left: centre(i) - dot / 2,
                    top: AppConstants.journeyBuddyHeight,
                    width: dot,
                    child: _slot(i),
                  ),
                Positioned(
                  left: centre(standOn) - AppConstants.journeyBuddyHeight / 2,
                  top: 0,
                  width: AppConstants.journeyBuddyHeight,
                  height: AppConstants.journeyBuddyHeight,
                  child: CustomPaint(
                    key: JourneyDots.buddyKey,
                    painter: BuddyPainter(_buddy),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _slot(int i) {
    final day = i < widget.days.length ? widget.days[i] : null;
    final circle = Container(
      key: JourneyDots.dotKey(i),
      width: AppConstants.journeyDotSize,
      height: AppConstants.journeyDotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: day == null ? AppTheme.background : AppTheme.primary,
        border: day == null
            ? Border.all(
                color: AppTheme.border,
                width: AppConstants.borderWidthMd,
              )
            : Border.all(
                color: AppTheme.buddyOutline,
                width: AppConstants.borderWidthMd,
              ),
      ),
      child: day == null
          ? null
          : const Icon(
              Icons.check,
              size: AppConstants.iconSizeXs,
              color: AppTheme.buddyOutline,
            ),
    );
    return Column(
      children: [
        i == _bumped
            ? ScaleTransition(scale: _bump.drive(_scale), child: circle)
            : circle,
        const SizedBox(height: AppConstants.spacing2),
        if (day != null && day.gutFeeling)
          Container(
            key: JourneyDots.pipKey,
            width: AppConstants.journeyPipSize,
            height: AppConstants.journeyPipSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.careGut,
            ),
          )
        else
          const SizedBox(height: AppConstants.journeyPipSize),
      ],
    );
  }
}
